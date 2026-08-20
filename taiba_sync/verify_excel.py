#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
verify_excel.py
===============
مقارنة قائمة منتجات السوبيرات (Excel) مع منتجات Deliv في الـ VPS بالاسم + الحجم.
- يقرأ Excel (اسم فيه الحجم غالباً).
- يجلب منتجات Deliv (اسم + حقل capacite).
- المطابقة: كلمات اسم Deliv كلها موجودة في اسم Excel، والحجم يطابق إن وُجد.
- تقرير بالمطابقات والمشاكل.
"""

import argparse
import csv
import os
import sys

sys.stdout.reconfigure(encoding='utf-8')

import openpyxl
import sync_taiba_images as st


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--excel', default=r'D:\منتجات.xlsx')
    ap.add_argument('--out', default=None)
    args = ap.parse_args()

    wb = openpyxl.load_workbook(args.excel, data_only=True)
    ws = wb.active
    excel = []
    for row in ws.iter_rows(min_row=2, values_only=True):
        if not row or not row[0]:
            continue
        excel.append((str(row[0]).strip(), str(row[1]).strip() if len(row) > 1 else ''))
    print('[+] Excel products: %d' % len(excel))

    print('[*] جلب منتجات Deliv ...')
    our = st.fetch_our_products()
    print('[+] Deliv products: %d' % len(our))

    deliv = []
    for p in our:
        n = p.get('name') or ''
        toks = st.tokenize(n)
        sz = st.our_sizes(p)
        deliv.append({'p': p, 'name': n, 'toks': toks, 'size': sz, 'n_tox': len(toks)})

    matched = 0
    problems = []
    for xname, xprice in excel:
        xtoks = st.tokenize(xname)
        xsz = st.our_sizes({'name': xname, 'capacite': ''})
        if not xtoks:
            problems.append((xname, xprice, '', 'اسم بدون كلمات'))
            continue

        best = None
        for d in deliv:
            if not d['toks'] or not d['toks'] <= xtoks:
                continue
            # تفضيل: مطابقة الحجم إن وجد الاثنان
            size_ok = True
            if xsz and d['size'] and not st.sizes_match(xsz, d['size']):
                size_ok = False
            if not size_ok:
                continue
            # الاسم الأطول (الأكثر تحديداً) أفضل من الاسم القصير العام
            score = (d['n_tox'], 1 if (xsz and d['size'] and st.sizes_match(xsz, d['size'])) else 0)
            if best is None or score > best[0]:
                best = (score, d)

        if best is None:
            problems.append((xname, xprice, '', 'لا يوجد مطابقة اسم في Deliv'))
            continue
        d = best[1]
        if xsz and d['size'] and not st.sizes_match(xsz, d['size']):
            problems.append((xname, xprice, d['name'],
                             'حجم مختلف: excel=%s deliv=%s' % (st.fmt_sizes(xsz), st.fmt_sizes(d['size']))))
        elif not xsz and d['size']:
            problems.append((xname, xprice, d['name'], 'Excel بلا حجم وDeliv عندها حجم=%s' % st.fmt_sizes(d['size'])))
        else:
            matched += 1

    print('\n===== ملخص الـ Excel مقابل Deliv (اسم+حجم) =====')
    print('  مطابق: %d / %d' % (matched, len(excel)))
    print('  مشاكل: %d' % len(problems))

    out_path = args.out or os.path.join(st.OUT_DIR, 'excel_vs_deliv_namesize.csv')
    with open(out_path, 'w', newline='', encoding='utf-8-sig') as f:
        w = csv.writer(f)
        w.writerow(['excel_name', 'excel_price', 'deliv_name', 'problem'])
        for row in problems:
            w.writerow(row)
    print('  التقرير: %s' % out_path)

    if problems:
        print('\n--- المشاكل ---')
        for xname, xprice, dname, prob in problems:
            print('  %s | %s | %s | %s' % (xname, xprice, dname, prob))


if __name__ == '__main__':
    main()
