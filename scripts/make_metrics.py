#!/usr/bin/env python3
"""
make_metrics.py - gom so lieu tu flow go tay thanh results/metrics.csv (dang "Metric,Value" nhu OpenLane).
Tac gia: Khoadang

Cach chay (tu bat ky dau):   python3 ~/openlane2/designs/uart/scripts/make_metrics.py
Tuy chon:  --root DIR   thu muc design (mac dinh: thu muc cha cua scripts/)
           --def FILE   DEF dung de dem cell/day (mac dinh: results/uart.def)

Doc: results/uart.def, reports/route_wirelength.rpt, final_area.rpt, final_timing.rpt, final_power.rpt,
     uart.drc, drc_magic.rpt, lvs_netgen.rpt, synth_area.rep   (file nao thieu thi bo qua dong do)
Dau ra: results/metrics.csv
"""
import argparse, os, re, sys

ap = argparse.ArgumentParser()
ap.add_argument('--root', default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ap.add_argument('--def', dest='deff', default=None)
ap.add_argument('--out', default=None)
a = ap.parse_args()
_base = os.path.join(a.root, 'run') if os.path.isdir(os.path.join(a.root, 'run')) else a.root   # lan chay hien tai (symlink run/) neu co
R = os.path.join(_base, 'results'); P = os.path.join(_base, 'reports')
DEF = a.deff or os.path.join(R, 'uart.def')
OUT = a.out or os.path.join(R, 'metrics.csv')
m = {}                       # key -> value (giu thu tu chen)
notes = []

def rd(path):
    try:
        return open(path).read()
    except OSError:
        notes.append('thieu file: ' + path); return None

# ---------------------------- DEF: dem cell, dien tich die/core, chieu dai day ----------------------------
d = rd(DEF)
if d:
    dbu = float(re.search(r'UNITS DISTANCE MICRONS (\d+)', d).group(1))
    x1, y1, x2, y2 = map(float, re.search(r'DIEAREA \( (-?\d+) (-?\d+) \) \( (-?\d+) (-?\d+) \)', d).groups())
    m['design__die__area'] = round((x2 - x1) * (y2 - y1) / dbu / dbu, 1)
    # core = bao hinh chu nhat cac ROW
    rows = re.findall(r'^ROW \S+ \S+ (-?\d+) (-?\d+) \S+ DO (\d+) BY (\d+) STEP (\d+) (\d+)', d, re.M)
    if rows:
        ys = sorted({int(r[1]) for r in rows})
        rh = (ys[1] - ys[0]) if len(ys) > 1 else 2720
        cx1 = min(int(r[0]) for r in rows); cx2 = max(int(r[0]) + int(r[2]) * int(r[4]) for r in rows)
        cy1 = ys[0]; cy2 = ys[-1] + rh
        m['design__core__area'] = round((cx2 - cx1) * (cy2 - cy1) / dbu / dbu, 1)
    comp = re.search(r'^COMPONENTS \d+ ;(.*?)^END COMPONENTS', d, re.S | re.M).group(1)
    insts = re.findall(r'^\s*- (\S+) (\S+)', comp, re.M)          # (ten instance, ten cell)
    cls = {'fill': 0, 'tap': 0, 'seq': 0, 'clkbuf': 0, 'hold': 0, 'other': 0}
    for name, cell in insts:
        c = cell.replace('sky130_fd_sc_hd__', '').replace('sky130_ef_sc_hd__', '')
        if c.startswith(('fill', 'decap')) or name.startswith('FILLER'): cls['fill'] += 1
        elif c.startswith('tap') or name.startswith('TAP'): cls['tap'] += 1
        else:
            cls['other'] += 1
            if re.match(r'(df|sdf|edf|dlx|dlr|dlt)', c): cls['seq'] += 1
            if name.startswith(('clkbuf_', 'clkload', 'clkinv')): cls['clkbuf'] += 1
            if name.startswith('hold'): cls['hold'] += 1
    m['design__instance__count'] = cls['other'] + cls['tap']
    m['design__instance__count__class:sequential_cell'] = cls['seq']
    m['design__instance__count__class:fill_cell'] = cls['fill']
    m['design__instance__count__class:tap_cell'] = cls['tap']
    m['design__instance__count__hold_buffer'] = cls['hold']
    m['design__instance__count__class:clock_buffer_or_load'] = cls['clkbuf']

# chieu dai day: do bang odb (buoc 06) -> reports/route_wirelength.rpt (so nguyen, um)
w = rd(os.path.join(P, 'route_wirelength.rpt'))
if w and w.strip():
    m['route__wirelength'] = int(float(w.strip().split()[0]))

# ---------------------------- area / utilization ----------------------------
t = rd(os.path.join(P, 'final_area.rpt'))
if t:
    g = re.search(r'Design area ([\d.]+) u\^2 (\d+)% utilization', t)
    if g:
        m['design__instance__area'] = float(g.group(1))
        m['design__instance__utilization'] = round(int(g.group(2)) / 100, 6)
t = rd(os.path.join(P, 'synth_area.rep'))
if t:
    g = re.findall(r"Chip area for (?:top )?module '\\?\S+': ([\d.]+)", t)
    if g: m['synthesis__chip_area'] = float(g[-1])

# ---------------------------- timing ----------------------------
t = rd(os.path.join(P, 'final_timing.rpt'))
if t:
    ws = re.findall(r'^worst slack (-?[\d.]+)', t, re.M)
    if len(ws) >= 2:
        m['timing__setup__ws'] = float(ws[0]); m['timing__hold__ws'] = float(ws[1])
    tn = re.search(r'^tns (-?[\d.]+)', t, re.M)
    if tn: m['timing__setup__tns'] = float(tn.group(1))
    sect = None; cnt = {'max fanout': 0, 'max slew': 0, 'max capacitance': 0}
    for line in t.split('\n'):
        s = line.strip()
        if s in cnt: sect = s; continue
        if sect and 'VIOLATED' in line: cnt[sect] += 1
    m['design__max_fanout_violation__count'] = cnt['max fanout']
    m['design__max_slew_violation__count'] = cnt['max slew']
    m['design__max_cap_violation__count'] = cnt['max capacitance']

# ---------------------------- power (W) ----------------------------
t = rd(os.path.join(P, 'final_power.rpt'))
if t:
    g = re.search(r'^Total\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)', t, re.M)
    if g:
        for k, v in zip(['power__internal__total', 'power__switching__total', 'power__leakage__total', 'power__total'], g.groups()):
            m[k] = float(v)

# ---------------------------- DRC / LVS ----------------------------
t = rd(os.path.join(P, 'uart.drc'))
if t is not None:
    m['route__drc_errors'] = len(re.findall(r'^violation type', t, re.M))
t = rd(os.path.join(P, 'drc_magic.rpt'))
if t:
    g = re.search(r'DRC total violation boxes: (\d+)', t)
    if g: m['magic__drc_error__count'] = int(g.group(1))
t = rd(os.path.join(P, 'lvs_netgen.rpt'))
if t:
    ok = 'Circuits match uniquely' in t
    m['design__lvs_error__count'] = 0 if ok else 1

with open(OUT, 'w') as f:
    f.write('Metric,Value\n')
    for k, v in m.items(): f.write('%s,%s\n' % (k, v))
print('da ghi %s (%d chi so)' % (OUT, len(m)))
for n in notes: print('  luu y:', n)
