#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
sync_taiba_images.py
====================
مزامنة صور المنتجات من متجر taibaoline.com إلى متجر Deliv.

الفكرة:
  1. نجلب كل منتجات طيبة عبر واجهة WooCommerce الرسمية (Store API مفتوحة).
  2. نجلب كل منتجاتنا عبر API ديليف.
  3. نطابق بالاسم + الحجم (المقاس) — الاسم لازم يطابق والحجم لازم يطابق.
  4. نختار صورة المنتج من طيبة (نفضّل الصور الشفافة PNG، وإن لم توجد نأخذ أي صورة).
  5. نرفع الصورة لسيرفر ديليف ونحدّث المنتج.

الوضع الافتراضي = Dry-run (تجربة بدون تغيير): ينتج تقرير matches فقط.
للتطبيق الفعلي: --apply أو --apply-all.

استعمال:
  python sync_taiba_images.py                          # تقرير فقط (بدون تغيير)
  python sync_taiba_images.py --apply                  # يطبّق المطابقات HIGH الموثوقة فقط
  python sync_taiba_images.py --apply-all              # يطبّق كل المطابقات
  python sync_taiba_images.py --taiba-category 3601    # منتجات المواد الغذائية فقط
  python sync_taiba_images.py --only-missing           # المنتجات التي بلا صورة فقط
  python sync_taiba_images.py --limit-our 50           # تجربة على أول 50 منتج
  python sync_taiba_images.py --allow-dup              # اسمح بالتكرار (نفس منتج طيبة -> عدة منتجات)
  python sync_taiba_images.py --allow-common           # اسمح بمطابقات بلا كلمة مميزة مشتركة
  python sync_taiba_images.py --revert-report FILE.csv # استرجاع الصور القديمة من تقرير مطبّق
  python sync_taiba_images.py --excel "D:\\منتجات.xlsx" # استعمل قائمة Excel كمنتجات السوبيرات

الأسرار (لا ترفع للـ GitHub):
  ADMIN_USER / ADMIN_PASS في قسم CONFIG.
"""

import argparse
import csv
import html
import json
import os
import re
import sys
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
from difflib import SequenceMatcher

# ============================ CONFIG ============================
API_BASE = 'https://api.delivap.com'
STORE_ID = '6a6602347955f9147da3ee2a'
ADMIN_USER = 'omranywalyd'
ADMIN_PASS = 'kkaassoommaa'

TAIBA_BASE = 'https://www.taibaoline.com'
TAIBA_API = TAIBA_BASE + '/wp-json/wc/store/v1/products'
TAIBA_FOOD_CATEGORY = '3601'  # المواد الغذائية

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'output')
UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36'

# ============================ HTTP ============================

def http_get_bytes(url, headers=None, tries=3):
    last = None
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers=dict({'User-Agent': UA}, **(headers or {})))
            with urllib.request.urlopen(req, timeout=90) as r:
                return r.read()
        except Exception as e:
            last = e
            time.sleep(2 * (i + 1))
    raise last


def http_get_json(url, headers=None, tries=3):
    raw = http_get_bytes(url, headers, tries)
    return json.loads(raw.decode('utf-8'))


def http_json(method, url, payload=None, headers=None, tries=3):
    body = json.dumps(payload).encode('utf-8') if payload is not None else None
    h = {'User-Agent': UA}
    if body is not None:
        h['Content-Type'] = 'application/json'
    if headers:
        h.update(headers)
    last = None
    for i in range(tries):
        try:
            req = urllib.request.Request(url, data=body, method=method, headers=h)
            with urllib.request.urlopen(req, timeout=90) as r:
                raw = r.read().decode('utf-8')
                return (json.loads(raw) if raw else {}), r.status
        except urllib.error.HTTPError as e:
            raw = e.read().decode('utf-8')
            if i == tries - 1:
                try:
                    return (json.loads(raw) if raw else {}), e.code
                except Exception:
                    return {'error': raw}, e.code
            last = e
            time.sleep(2 * (i + 1))
        except Exception as e:
            if i == tries - 1:
                raise
            last = e
            time.sleep(2 * (i + 1))
    raise last


# ============================ DELIV API ============================

def admin_login():
    data, code = http_json('POST', API_BASE + '/api/admin/login',
                           {'username': ADMIN_USER, 'password': ADMIN_PASS})
    token = data.get('token')
    if not token:
        raise SystemExit('LOGIN FAILED (code=%s): %s' % (code, json.dumps(data, ensure_ascii=False)))
    return token


def fetch_our_products():
    out = []
    skip = 0
    limit = 200
    while True:
        data = http_get_json('%s/api/products?storeId=%s&limit=%d&skip=%d' % (API_BASE, STORE_ID, limit, skip))
        out.extend(data)
        if len(data) < limit:
            break
        skip += limit
    return out


def load_excel(path):
    import openpyxl
    wb = openpyxl.load_workbook(path, data_only=True)
    ws = wb.active
    rows = []
    for r in ws.iter_rows(min_row=2, values_only=True):
        if not r or not r[0]:
            continue
        rows.append({'name': str(r[0]).strip(),
                     'prix': str(r[1]).strip() if len(r) > 1 else ''})
    return rows


def map_excel(rows, our_products):
    deliv = [{'p': p, 'toks': tokenize(p.get('name') or '')} for p in our_products]
    deliv = [d for d in deliv if d['toks']]
    mapped = []
    for row in rows:
        xtoks = tokenize(row['name'])
        if not xtoks:
            continue
        best = None
        for d in deliv:
            if d['toks'] <= xtoks:
                score = len(d['toks'])
                if best is None or score > best[0]:
                    best = (score, d)
        item = dict(row)
        if best:
            item['_id'] = best[1]['p'].get('_id', '')
            item['image'] = best[1]['p'].get('image') or ''
        else:
            item['_id'] = ''
            item['image'] = ''
        mapped.append(item)
    return mapped


def upload_image(token, image_bytes, filename, content_type='image/png'):
    boundary = '----delivsync' + os.urandom(8).hex()
    head = ('--%s\r\nContent-Disposition: form-data; name="file"; filename="%s"\r\n'
            'Content-Type: %s\r\n\r\n' % (boundary, filename, content_type)).encode()
    tail = ('\r\n--%s--\r\n' % boundary).encode()
    body = head + image_bytes + tail
    req = urllib.request.Request(API_BASE + '/api/upload', data=body, method='POST',
                                 headers={'User-Agent': UA,
                                          'Content-Type': 'multipart/form-data; boundary=%s' % boundary,
                                          'Authorization': 'Bearer ' + token})
    with urllib.request.urlopen(req, timeout=180) as r:
        return json.loads(r.read().decode('utf-8'))


def update_product(token, pid, image_url):
    data, code = http_json('PUT', API_BASE + '/api/admin/products/' + pid,
                           {'image': image_url},
                           headers={'Authorization': 'Bearer ' + token})
    return data, code


def revert_from_report(token, csv_path):
    print('[*] استرجاع الصور القديمة من %s ...' % csv_path)
    with open(csv_path, encoding='utf-8-sig') as f:
        rows = list(csv.DictReader(f))
    ok = err = skip = 0
    for r in rows:
        if r.get('action') != 'UPDATED':
            continue
        pid = (r.get('our_id') or '').strip()
        old = (r.get('old_image') or '').strip()
        if not pid:
            skip += 1
            continue
        data, code = update_product(token, pid, old)
        if code in (200, 201):
            ok += 1
            print('    [OK] %s <- استرجعت الصورة القديمة%s' % (
                ((r.get('our_name') or '').strip() or pid),
                '' if old else ' (كانت بلا صورة -> أصبحت بلا صورة)'))
        else:
            err += 1
            print('    [ERR] %s code=%s %s' % ((r.get('our_name') or '').strip() or pid, code,
                                                json.dumps(data, ensure_ascii=False)[:200]))
    print('\n===== الاسترجاع =====')
    print('  مسترجَع: %d | فشل: %d | بلا صورة قديمة: %d' % (ok, err, skip))


# ============================ NORMALISATION ============================

_AR_TBL = str.maketrans({'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ة': 'ه', 'ى': 'ي', 'ؤ': 'و', 'ئ': 'ي', 'ء': ''})


def strip_diacritics(t):
    return ''.join(c for c in t if not unicodedata.combining(c))


def normalize(t):
    return strip_diacritics(t.lower()).translate(_AR_TBL)


def strip_tags(t):
    return re.sub(r'<[^>]+>', ' ', t or '')


_STOP = {
    'ال', 'من', 'في', 'على', 'الى', 'الي', 'و', 'ب', 'ل', 'ك', 'ف', 'مع', 'كل', 'س', 'دج',
    'le', 'la', 'les', 'de', 'du', 'des', 'un', 'une', 'et', 'au', 'aux', 'avec', 'pour',
    'sur', 'en', 'a', 'est', 'sans',
    # وحدات الحجم والوزن: لا تميز المنتج وتسبب مطابقة خاطئة (مثل "افري1 لتر" مع أي حليب)
    'لتر', 'ليتر', 'مل', 'كغ', 'كج', 'كلغ', 'غرام', 'غرم', 'كيلو', 'كلو', 'كيلوغرام',
    'litre', 'litres', 'liter', 'liters', 'ml', 'kg', 'cl', 'cc', 'gr', 'gramme',
    'grammes', 'gram', 'grams', 'kilogramme',
    # كلمات تغليف/كميات: لا تميز المنتج
    'كرطونة', 'علبة', 'قطعة', 'كيس', 'زجاجة', 'زجاج', 'بلاستيك', 'عدد',
    # كلمات ضعيفة: "بدون غلوتين" في علامات منتج آخر لا يجعل الخميرة "مقرون بدون غلوتين"
    'بدون', 'عادي', 'طبيعي', 'برومو', 'رمضان', 'جديد',
}

# عدد مرات الظهور المسموح للكلمة في منتجات طيبة حتى تبقى "مميزة".
# الكلمات الشائعة (مثل "بدون غلوتين" التي تظهر في عشرات المنتجات) لا تُحسب في التغطية.
# نرفع العتبة قليلاً حتى تبقى أسماء الماركات (مثل صومام، معطر الجو) مميزة.
DISTINCT_DF = 150


def tokenize(t):
    toks = set()
    for m in re.findall(r'[a-z0-9\u0600-\u06ff]+', normalize(t)):
        # نفصل الأرقام عن الحروف ("فينوس250مل" -> فينوس / 250 / مل) حتى لا تضيع الماركة
        for part in re.findall(r'[a-z]+|[0-9]+|[\u0600-\u06ff]+', m):
            if part and part not in _STOP and len(part) >= 2:
                toks.add(part)
    return toks


# ============================ الحجم (Size) ============================

_SIZE_PATTERNS = [
    (r'(\d+(?:[.,]\d+)?)\s*(?:لتر|ليتر|litre|liters?)\b', 'l'),
    (r'(\d+(?:[.,]\d+)?)\s*ل\b', 'l'),
    (r'(\d+(?:[.,]\d+)?)\s*l\b', 'l'),
    (r'(\d+(?:[.,]\d+)?)\s*(?:مل|ml)\b', 'ml'),
    (r'(\d+(?:[.,]\d+)?)\s*cl\b', 'cl'),
    (r'(\d+(?:[.,]\d+)?)\s*(?:كغ|كج|كلغ|kg)\b', 'kg'),
    (r'(\d+(?:[.,]\d+)?)\s*(?:غ|غرام|g|gr|gramme)\b', 'g'),
]


def extract_sizes(text):
    text = normalize(text or '')
    text = re.sub(r',\s+(\d)', r',\1', text)
    sizes = []
    for pat, unit in _SIZE_PATTERNS:
        for m in re.finditer(pat, text):
            try:
                val = float(m.group(1).replace(',', '.'))
            except ValueError:
                continue
            sizes.append((unit, val))
    return sizes


def canonical(sizes):
    out = []
    for unit, val in sizes:
        if unit == 'l':
            out.append(('vol', val * 1000))
        elif unit == 'ml':
            out.append(('vol', val))
        elif unit == 'cl':
            out.append(('vol', val * 10))
        elif unit == 'kg':
            out.append(('wt', val * 1000))
        elif unit == 'g':
            out.append(('wt', val))
    return sorted(set(out))


def sizes_match(a, b):
    # تحمل 2% + 10 وحدة: يكفي لاختلافات التقريب، ويمنع "عسل 1كغ" مع "950غ"
    for x in a:
        for y in b:
            if x[0] == y[0]:
                if abs(x[1] - y[1]) <= max(10, 0.02 * max(x[1], y[1])):
                    return True
    return False


def our_sizes(p):
    name = p.get('name') or ''
    cap = str(p.get('capacite') or '')
    sizes = extract_sizes(name + ' ' + cap)
    c = cap.strip().replace(',', '.')
    if c and '/' not in c and re.fullmatch(r'\d+(?:\.\d+)?', c):
        v = float(c)
        if 0 < v <= 10:
            sizes.append(('l', v))
    return canonical(sizes)


def taiba_sizes(p):
    txt = html.unescape((p.get('name') or '')) + ' ' + strip_tags(html.unescape(p.get('description') or ''))
    return canonical(extract_sizes(txt))


def fmt_sizes(sizes):
    parts = []
    for kind, val in sizes:
        if kind == 'vol':
            parts.append('%gL' % (val / 1000.0) if val >= 1000 else '%gml' % val)
        else:
            parts.append('%gkg' % (val / 1000.0) if val >= 1000 else '%gg' % val)
    return ','.join(parts) if parts else ''


# ============================ MATCHING ============================

def classify(name_score, size_match, our_size_known, cov):
    # HIGH لا يأتي أبداً من تطابق لفظي (fuzzy) فقط؛ التغطية الفعلية شرط.
    # "افري1 لتر" كان يصل HIGH بـ fuzzy (0.56) رغم أن التغطية 0.5 فقط.
    if size_match and cov >= 0.55:
        return 'HIGH'
    if size_match and name_score >= 0.35:
        return 'MEDIUM'
    if (not our_size_known) and name_score >= 0.65:
        return 'MEDIUM'
    return 'LOW'


CONF_RANK = {'HIGH': 3, 'MEDIUM': 2, 'LOW': 1}


def is_distinctive(tok, df):
    if any(c.isdigit() for c in tok):
        return False
    return df.get(tok, 0) <= DISTINCT_DF


def build_taiba_index(products):
    records = []
    index = {}
    df = {}
    for idx, p in enumerate(products):
        name = html.unescape(p.get('name') or '')
        desc = strip_tags(html.unescape(p.get('description') or ''))
        tags = ' '.join(html.unescape(t.get('name', '')) for t in (p.get('tags') or []))
        toks = tokenize(name + ' ' + desc + ' ' + tags)
        sizes = taiba_sizes(p)
        records.append({'p': p, 'name': name, 'desc': desc, 'tags': tags,
                        'toks': toks, 'sizes': sizes})
        for t in toks:
            index.setdefault(t, []).append(idx)
            df[t] = df.get(t, 0) + 1
    return records, index, df


def match_all(our_products, records, index, df):
    results = []
    for op in our_products:
        our_toks = tokenize(op.get('name') or '')
        distinct_our = {t for t in our_toks if is_distinctive(t, df)}
        our_sz = our_sizes(op)
        if not our_toks:
            continue
        cand = set()
        for t in our_toks:
            cand.update(index.get(t, []))
        best = None
        for idx in cand:
            rec = records[idx]
            tp = rec['p']
            distinct_inter = distinct_our & rec['toks']
            cov = len(distinct_inter) / len(distinct_our) if distinct_our else 0.0
            norm_o = normalize(html.unescape(op.get('name') or ''))
            norm_t = normalize((html.unescape(tp.get('name') or '') + ' ' + strip_tags(html.unescape(tp.get('description') or ''))))
            fuzzy = SequenceMatcher(None, norm_o, norm_t).ratio()
            name_score = max(cov, fuzzy)
            if our_sz:
                if not rec['sizes'] or not sizes_match(our_sz, rec['sizes']):
                    continue
                size_match = True
            else:
                size_match = False
            conf = classify(name_score, size_match, bool(our_sz), cov)
            score = name_score + (0.5 if size_match else 0.0)
            if distinct_our and not distinct_inter:
                flag = 'COMMON_ONLY'
            elif distinct_our and len(distinct_inter) < len(distinct_our):
                flag = 'BRAND_GAP'
            else:
                flag = ''
            item = {
                'taiba_idx': idx,
                'taiba': tp,
                'name_score': round(name_score, 3),
                'coverage': round(cov, 3),
                'fuzzy': round(fuzzy, 3),
                'size_match': size_match,
                'our_size_known': bool(our_sz),
                'our_sizes': our_sz,
                'taiba_sizes': rec['sizes'],
                'confidence': conf,
                'score': round(score, 3),
                'flag': flag,
                'distinct_our': len(distinct_our),
                'distinct_inter': len(distinct_inter),
            }
            if best is None or score > best['score']:
                best = item
        if best:
            results.append({'our': op, 'match': best})
    return results


# ============================ IMAGE ============================

_TRANSPARENT_HINTS = ('remove-bg', 'removebg', 'snapbg', 'transparent', '-bg.')


def direct_url(src):
    m = re.search(r'(/wp-content/uploads/[^?]+)', src)
    if m:
        return TAIBA_BASE + urllib.parse.unquote(m.group(1))
    return src


def is_transparent(u):
    low = direct_url(u).lower()
    return any(h in low for h in _TRANSPARENT_HINTS)


def is_png(u):
    return urllib.parse.urlparse(direct_url(u)).path.lower().endswith('.png')


def pick_image(taiba):
    imgs = [i.get('src') or '' for i in (taiba.get('images') or []) if i.get('src')]
    if not imgs:
        return None

    def rank(u):
        if is_transparent(u):
            return 3
        if is_png(u):
            return 2
        return 1

    imgs.sort(key=rank, reverse=True)
    return imgs[0]


def img_ext(url):
    path = urllib.parse.urlparse(direct_url(url)).path.lower()
    for e in ('.png', '.jpg', '.jpeg', '.webp', '.gif'):
        if path.endswith(e):
            return e
    return '.png'


CTYPES = {'.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg',
          '.webp': 'image/webp', '.gif': 'image/gif'}


# ============================ REPORT ============================

def ensure_outdir():
    os.makedirs(OUT_DIR, exist_ok=True)


def write_reports(rows, min_conf):
    stamp = time.strftime('%Y%m%d-%H%M%S')
    csv_path = os.path.join(OUT_DIR, 'report_matches_%s.csv' % stamp)
    md_path = os.path.join(OUT_DIR, 'report_matches_%s.md' % stamp)
    header = ['our_id', 'our_name', 'our_price', 'our_capacite', 'our_size',
              'taiba_id', 'taiba_name', 'taiba_price', 'taiba_size',
              'name_score', 'coverage', 'fuzzy', 'size_match', 'confidence',
              'flag', 'image_url', 'image_transparent', 'action', 'old_image', 'new_image', 'error']
    with open(csv_path, 'w', newline='', encoding='utf-8-sig') as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)
    with open(md_path, 'w', encoding='utf-8') as f:
        f.write('# تقرير مطابقة الصور taibaoline -> Deliv\n\n')
        f.write('الوقت: %s | الحد الأدنى للثقة: %s | النتائج: %d\n\n' % (stamp, min_conf, len(rows)))
        f.write('| ' + ' | '.join(header) + ' |\n')
        f.write('|' + '---|' * len(header) + '\n')
        for r in rows:
            f.write('| ' + ' | '.join(str(x).replace('|', '/') for x in r) + ' |\n')
    return csv_path, md_path


# ============================ MAIN ============================

def main():
    ap = argparse.ArgumentParser(description='مزامنة صور المنتجات من taibaoline إلى Deliv')
    ap.add_argument('--apply', action='store_true', help='تطبيق المطابقات HIGH فقط')
    ap.add_argument('--apply-all', action='store_true', help='تطبيق كل المطابقات')
    ap.add_argument('--taiba-category', default=None,
                    help='تصنيف طيبة (مثال 3601 = المواد الغذائية). إن لم يُحدد نجلب كل شيء.')
    ap.add_argument('--only-missing', action='store_true', help='المنتجات التي بلا صورة فقط')
    ap.add_argument('--overwrite', action='store_true',
                    help='اسمح بتغيير صور المنتجات التي لها صورة أصلًا (افتراضي: نتعامل فقط مع بلا صورة)')
    ap.add_argument('--limit-our', type=int, default=0, help='الحد الأقصى لمنتجاتنا (للتجربة)')
    ap.add_argument('--min-confidence', default=None, choices=['HIGH', 'MEDIUM', 'LOW'],
                    help='أدنى ثقة للتطبيق (افتراضي HIGH مع --apply)')
    ap.add_argument('--allow-dup', action='store_true',
                    help='اسمح بالتطبيق عندما يطابق نفس منتج طيبة عدة منتجات عندنا')
    ap.add_argument('--allow-common', action='store_true',
                    help='اسمح بالتطبيق للمطابقات بلا كلمة مميزة مشتركة في الاسم')
    ap.add_argument('--revert-report', metavar='CSV', default=None,
                    help='استرجاع الصور القديمة من تقرير مطبّق (يعيد old_image لكل صف action=UPDATED)')
    ap.add_argument('--excel', metavar='PATH', default=None,
                    help='ملف Excel لقائمة منتجات السوبيرات (يُربط بمنتجات Deliv بالاسم)')
    ap.add_argument('--debug-tokens', type=int, default=0,
                    help='اطبع أكثر N كلمة شيوعاً في منتجات طيبة')
    args = ap.parse_args()

    ensure_outdir()

    if args.apply_all:
        min_conf = args.min_confidence or 'LOW'
    elif args.apply:
        min_conf = args.min_confidence or 'HIGH'
    else:
        min_conf = args.min_confidence or 'HIGH'

    print('[*] تسجيل الدخول إلى Deliv ...')
    token = admin_login()
    print('[+] تم الدخول')

    if args.revert_report:
        revert_from_report(token, args.revert_report)
        return

    print('[*] جلب منتجاتنا ...')
    all_our = fetch_our_products()
    print('[+] منتجات Deliv: %d' % len(all_our))
    if args.excel:
        print('[*] قراءة قائمة السوبيرات من Excel ...')
        rows = load_excel(args.excel)
        print('[+] Excel: %d منتج' % len(rows))
        our = map_excel(rows, all_our)
        unmatched = [o for o in our if not o.get('_id')]
        print('[+] بعد الربط بالاسم مع Deliv: %d (غير مرتبط: %d)' % (len(our), len(unmatched)))
        for o in unmatched:
            print('    [غير مرتبط] %s' % o['name'])
    else:
        our = all_our
    # افتراضياً نعالج فقط المنتجات بلا صورة حتى لا نمسح صوراً جيدة؛
    # استعمل --overwrite لتغيير الصور الموجودة أيضاً.
    if args.only_missing or not args.overwrite:
        our = [p for p in our if not (p.get('image') or '').strip()]
    if args.limit_our:
        our = our[:args.limit_our]
    print('[+] منتجاتنا: %d' % len(our))

    cat_label = args.taiba_category or 'ALL'
    print('[*] جلب منتجات طيبة (التصنيف: %s) ...' % cat_label)
    taiba = []
    page = 1
    per = 100
    while True:
        url = '%s?per_page=%d&page=%d&orderby=id' % (TAIBA_API, per, page)
        if args.taiba_category:
            url += '&category=%s' % args.taiba_category
        data = http_get_json(url)
        if not data:
            break
        taiba.extend(data)
        print('    ... صفحة %d (المجموع %d)' % (page, len(taiba)))
        page += 1
        if len(data) < per:
            break
        time.sleep(0.3)
    print('[+] منتجات طيبة: %d' % len(taiba))

    print('[*] بناء فهرس المطابقة ...')
    records, index, df = build_taiba_index(taiba)
    print('[+] الفهرس جاهز (%d سجل)' % len(records))

    if args.debug_tokens:
        from collections import Counter
        c = Counter()
        for rec in records:
            c.update(rec['toks'])
        print('[*] أكثر %d كلمة شيوعاً:' % args.debug_tokens)
        for tok, n in c.most_common(args.debug_tokens):
            print('    %-16s %d' % (tok, n))

    print('[*] المطابقة ...')
    results = match_all(our, records, index, df)
    print('[+] نتائج المطابقة: %d' % len(results))

    src_counts = {}
    best_src = {}
    for res in results:
        tid = res['match']['taiba'].get('id')
        src_counts[tid] = src_counts.get(tid, 0) + 1
        s = res['match']['score']
        if tid not in best_src or s > best_src[tid]:
            best_src[tid] = s

    rows = []
    stats = {'HIGH': 0, 'MEDIUM': 0, 'LOW': 0, 'UPDATED': 0, 'ERROR': 0, 'REVIEW': 0}
    for res in sorted(results, key=lambda r: CONF_RANK[r['match']['confidence']], reverse=True):
        op = res['our']
        m = res['match']
        tp = m['taiba']
        src = pick_image(tp)
        conf = m['confidence']
        stats[conf] = stats.get(conf, 0) + 1
        pid = op.get('_id', '')
        name = op.get('name') or ''
        tid = tp.get('id')
        dup = src_counts.get(tid, 0) > 1 and m['score'] < best_src.get(tid, 0)

        mflags = []
        if m.get('flag') in ('COMMON_ONLY', 'BRAND_GAP') and not args.allow_common:
            mflags.append(m.get('flag'))
        if dup and not args.allow_dup:
            mflags.append('DUP_SOURCE')
        flag = '+'.join(mflags)

        action = 'REVIEW' if (CONF_RANK[conf] < CONF_RANK[min_conf] or mflags) else 'APPLY'
        old_img = op.get('image') or ''
        new_img = ''
        error = ''
        trans = bool(src and is_transparent(src))

        if args.apply or args.apply_all:
            if CONF_RANK[conf] < CONF_RANK[min_conf]:
                action = 'SKIP_LOW_CONFIDENCE'
            elif mflags:
                action = 'REVIEW_' + flag
                stats['REVIEW'] += 1
            elif not src:
                action = 'NO_IMAGE_ON_TAIBA'
            else:
                try:
                    print('    [%s] %s <- %s' % (conf, name, (tp.get('name') or '')))
                    img_bytes = http_get_bytes(direct_url(src))
                    ext = img_ext(src)
                    up = upload_image(token, img_bytes, 'p%s%s' % (pid, ext), CTYPES.get(ext, 'image/png'))
                    new_img = up.get('url') or ''
                    if not new_img:
                        raise RuntimeError('upload returned no url: %s' % json.dumps(up))
                    data, code = update_product(token, pid, new_img)
                    if code not in (200, 201):
                        raise RuntimeError('update code=%s: %s' % (code, json.dumps(data, ensure_ascii=False)))
                    action = 'UPDATED'
                    stats['UPDATED'] += 1
                except Exception as e:
                    action = 'ERROR'
                    error = '%s: %s' % (type(e).__name__, e)
                    stats['ERROR'] += 1
        else:
            action = 'WOULD_%s' % action

        rows.append([
            pid, name, op.get('prix', ''), op.get('capacite', ''), fmt_sizes(m['our_sizes']),
            tp.get('id', ''), tp.get('name') or '', tp.get('prices', {}).get('price', ''),
            fmt_sizes(m['taiba_sizes']),
            m['name_score'], m['coverage'], m['fuzzy'], m['size_match'], conf,
            flag, src or '', trans, action, old_img, new_img, error,
        ])

    rows.sort(key=lambda r: CONF_RANK.get(r[13], 0), reverse=True)

    print('\n===== ملخص =====')
    for k, v in stats.items():
        print('  %s: %d' % (k, v))
    print('  المجموع: %d' % len(results))

    if rows:
        csv_path, md_path = write_reports(rows, min_conf)
        print('\nالتقارير:')
        print('  CSV: %s' % csv_path)
        print('  MD : %s' % md_path)
    else:
        print('\nلا توجد مطابقات.')


if __name__ == '__main__':
    main()
