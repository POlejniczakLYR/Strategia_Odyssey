import copy, json
from pptx import Presentation
from pptx.util import Inches, Pt, Emu
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.enum.shapes import MSO_SHAPE
from lxml import etree

W='/tmp/claude-0/-home-user/f6ab55da-836b-5216-8d17-8e5b37571c74/scratchpad/'
prs=Presentation(W+'pptx/template.pptx')
NBSP=' '
PURPLE=RGBColor(0x2D,0x2E,0x87); WHITE=RGBColor(255,255,255); INK=RGBColor(0x1F,0x20,0x50); MUTED=RGBColor(0x59,0x5A,0x7A)
NEUTRAL=RGBColor(0xED,0xED,0xF2); RULE=RGBColor(0xC8,0xC9,0xDE)
HEAT=[RGBColor(0xF1,0xF1,0xF8),RGBColor(0xDA,0xDA,0xEE),RGBColor(0xB6,0xB7,0xDD),RGBColor(0x87,0x88,0xC4),RGBColor(0x55,0x56,0xA6),PURPLE]
def hidx(p,th=(5,15,30,50,70)):
    for i,t in enumerate(th):
        if p<t: return i
    return 5
def n(v): return f"{v:,}".replace(',',NBSP)
def m(v,d=1): return f"{v/1e6:,.{d}f}".replace(',',' ').replace('.',',').replace(' ',NBSP)
def pc(a,b,d=1): return f"{100*a/b:.{d}f}".replace('.',',')+'%'

# ---------- usun slajdy 2-4 szablonu ----------
sldIdLst=prs.slides._sldIdLst
for sid in list(sldIdLst)[1:]:
    prs.part.drop_rel(sid.rId); sldIdLst.remove(sid)
# ---------- okladka ----------
cov=prs.slides[0]
for sh in cov.shapes:
    if sh.is_placeholder and sh.placeholder_format.idx==0:
        sh.text_frame.text='Piramida klientów i udział w rynku'
    elif sh.has_text_frame and 'April 2026' in sh.text_frame.text:
        r=sh.text_frame.paragraphs[0].runs[0]; r.text='Listopad 2026'
        for extra in sh.text_frame.paragraphs[0].runs[1:]: extra.text=''

LAY=prs.slide_layouts[16]  # 100 Content 2
def new_slide(title,notes,sub=None):
    s=prs.slides.add_slide(LAY)
    for ph in list(s.placeholders):
        if ph.placeholder_format.idx==0: ph.text_frame.text=title
        else: ph._element.getparent().remove(ph._element)
    s.notes_slide.notes_text_frame.text=notes
    if sub: text(s,0.35,1.0,8.6,0.26,sub,size=12,color=PURPLE,bold=True,name='Podtytul')
    return s
def text(s,x,y,w,h,t,size=8,color=MUTED,bold=False,align=PP_ALIGN.LEFT,name=None):
    tb=s.shapes.add_textbox(Inches(x),Inches(y),Inches(w),Inches(h)); tf=tb.text_frame; tf.word_wrap=True
    tf.margin_left=tf.margin_right=tf.margin_top=tf.margin_bottom=0
    runs=t if isinstance(t,list) else [(t,bold)]
    p=tf.paragraphs[0]; p.alignment=align
    for tx,b in runs:
        r=p.add_run(); r.text=tx; r.font.size=Pt(size); r.font.bold=b; r.font.color.rgb=color
    if name: tb.name=name
    return tb
def table(s,x,y,widths,rows,rh=0.26,size=8,name='Tabela'):
    """rows: list of rows; cell = dict(t, fill, color, bold, align) or str"""
    nr=len(rows); nc=len(widths)
    gf=s.shapes.add_table(nr,nc,Inches(x),Inches(y),Inches(sum(widths)),Inches(rh*nr)); gf.name=name
    tbl=gf.table
    # wylacz styl tabeli (banding) - kolory ustawiamy sami
    tblPr=tbl._tbl.tblPr; tblPr.set('firstRow','0'); tblPr.set('bandRow','0')
    for i,wd in enumerate(widths): tbl.columns[i].width=Inches(wd)
    for r in range(nr): tbl.rows[r].height=Inches(rh)
    merges=[]
    for r,row in enumerate(rows):
        for c,cell in enumerate(row):
            if cell is None: continue
            if isinstance(cell,str): cell={'t':cell}
            tc=tbl.cell(r,c)
            tc.margin_left=tc.margin_right=Inches(0.04); tc.margin_top=tc.margin_bottom=Inches(0.01)
            tc.vertical_anchor=MSO_ANCHOR.MIDDLE
            tc.fill.solid(); tc.fill.fore_color.rgb=cell.get('fill',WHITE)
            tf=tc.text_frame; tf.word_wrap=True
            lines=cell['t'].split('\n')
            for li,ln in enumerate(lines):
                p=tf.paragraphs[0] if li==0 else tf.add_paragraph()
                p.alignment=cell.get('align',PP_ALIGN.RIGHT)
                rr=p.add_run(); rr.text=ln; rr.font.size=Pt(cell.get('size',size)); rr.font.bold=cell.get('bold',False)
                rr.font.color.rgb=cell.get('color',INK); rr.font.italic=cell.get('italic',False)
            if 'span' in cell: merges.append((r,c,cell['span']))
    for r,c,(dr,dc) in merges: tbl.cell(r,c).merge(tbl.cell(r+dr-1,c+dc-1))
    return tbl
def H(t,align=PP_ALIGN.RIGHT,span=None):
    d={'t':t,'fill':PURPLE,'color':WHITE,'bold':True,'align':align}
    if span: d['span']=span
    return d

# ================= SLAJD 3: biznes linie (tabela) =================
mk={'IS':6049631,'FS':2635624,'MM':1531302,'KN':1502368,'STRATEGIC':731220,'PUBLIC':1179637,'INTERNATIONAL':503222}
fr={'IS':2578736,'FS':42618,'MM':5598,'KN':1481,'STRATEGIC':113,'PUBLIC':609,'INTERNATIONAL':225}
R=[('IS','1–40',92798,12947,fr['IS'],813152,mk['IS'],40449795),('FS','41–200',20911,9703,fr['FS'],1074681,mk['FS'],116699774),
('MM','201–500',4939,1614,fr['MM'],1067186,mk['MM'],59887682),('K&N','501–4000',1158,665,fr['KN'],1076973,mk['KN'],122399942),
('Strategic','4001+',110,80,fr['STRATEGIC'],794547,mk['STRATEGIC'],120305847),('Public (CA)','publ. 501+',390,90,fr['PUBLIC'],822043,mk['PUBLIC'],28811202),
('International','klienci DB',225,189,fr['INTERNATIONAL'],503222,mk['INTERNATIONAL'],91943807)]
X=[('Inne','–',21400,254,21400,233453,None,20211423),('Kwarantanna','–',134305,102,None,1156229,None,34982)]
def tot(L,lab): return (lab,'',sum(r[2] for r in L),sum(r[3] for r in L),sum((r[4] or 0) for r in L),sum(r[5] for r in L),sum((r[6] or 0) for r in L),sum(r[7] for r in L))
LR=tot(R,'Linie razem'); ZR=tot(R+X,'Razem')
def sh_heat(p): return hidx(p,(2,5,10,20,30))
rows=[[H('Biznes linia',PP_ALIGN.LEFT),H('Przedział',PP_ALIGN.LEFT),H('Klienci\n(grupy)'),H('w tym\naktywni'),H('Firmy\nrynek'),H('Prac. u\nklientów'),H('Prac. rynek\n(szac. GUS)'),H('Potencjał\nmln zł'),H('Sprzedaż\nmln zł'),H('Udział\nw rynku')]]
def rowfor(r,bold=False,fill=WHITE):
    lab,pz,g,a,f,db,ry,s=r
    out=[{'t':lab,'align':PP_ALIGN.LEFT,'bold':True,'fill':fill},{'t':pz,'align':PP_ALIGN.LEFT,'color':MUTED,'fill':fill},
         {'t':n(g),'bold':bold,'fill':fill},{'t':n(a),'fill':fill,'bold':bold},{'t':n(f) if f else 'w liniach','fill':fill,'bold':bold},
         {'t':n(db),'fill':fill,'bold':bold}]
    if ry:
        p=ry*592; shv=100*s/p; hi=sh_heat(shv)
        out+=[{'t':n(ry),'fill':fill,'bold':bold},{'t':m(p),'fill':fill,'bold':bold},{'t':m(s),'bold':True,'fill':fill},
              {'t':pc(s,p),'bold':True,'fill':HEAT[hi],'color':WHITE if hi>=4 else INK}]
    else:
        out+=[{'t':'w liniach','fill':fill},{'t':'–','fill':fill},{'t':m(s),'bold':True,'fill':fill},{'t':'–','fill':fill}]
    return out
for r in R: rows.append(rowfor(r))
rows.append(rowfor(LR,True,NEUTRAL))
for r in X: rows.append(rowfor(r))
rows.append(rowfor(ZR,True,NEUTRAL))
s3=new_slide('Biznes linie: udział w rynku',
 'Klient to grupa TOP_LEVEL (lider i spięte z nim NIP-y), w linii regionu SOLDTO lidera. Niczego nie przenosimy: Other SMB, Other CA i grupy bez regionu są w Inne, Kwarantanna osobno. NIP z kilkoma płatnikami liczymy raz, w grupie z biznes linii.\n\nSprzedaż liczymy tam, gdzie się odbyła: wszystkie faktury z 12 zamkniętych miesięcy wg regionu SOLDTO na fakturze – 600,7 mln zł.\n\nPotencjał linii to rynek w jej przedziale zatrudnienia: pracujący GUS podzieleni na przedziały wg rozkładu zatrudnienia w DB_BAZA, razy 592 zł. K&N 501–4000 i Strategic 4001+ bez sektora publicznego i klientów International; Public = sektor publiczny 501+; International = zatrudnienie jego klientów.\n\nFirmy rynek = klienci + firmy z Kwarantanny i niezarejestrowane z DB_BAZA w przedziale linii, przeskalowane do firm aktywnych GUS.',sub='Udział rośnie z wielkością klienta: IS 1,1%, Strategic i International 28–31%')
table(s3,0.35,1.34,[0.98,0.78,0.78,0.66,0.8,0.86,0.92,0.82,0.78,0.72],rows,rh=0.255,size=8,name='Tabela biznes linie')
text(s3,0.35,4.62,6.8,0.75,'Klient = grupa TOP_LEVEL w linii regionu lidera, bez przenoszenia. Sprzedaż = wszystkie faktury 12 mies. wg regionu SOLDTO z faktury. Rynek: pracujący GUS wg przedziałów zatrudnienia (DB_BAZA); K&N i Strategic bez sektora publicznego i klientów International. Firmy rynek = klienci + firmy z Kwarantanny i niezarejestrowane w przedziale linii, przeskalowane do GUS. Inne = Other SMB, Other CA, brak regionu.',size=7,name='Przypis')

# ================= SLAJD 4: piramida =================
s4=new_slide('Piramida biznes linii',
 'Ta sama treść co slajd 3, w formie piramidy. Od dołu: IS (1–40), FS (41–200), MM (201–500), na górze K&N (501–4000) i Strategic (4001+); górną część dzielą Public (sektor publiczny 501+) i International (jego klienci).\n\nNa warstwach: udział linii w całej naszej sprzedaży – IS 6,7%, FS 19,4%, MM 10,0%, K&N 20,4%, Strategic 20,0%, Public 4,8%, International 15,3% (Inne 3,4%).\n\nTabela: aktywni (grupy ze sprzedażą), portfel (grupy linii), firmy rynek, potencjał, sprzedaż, udział wartościowy (sprzedaż ÷ potencjał) i penetracja (aktywni ÷ firmy rynek). Szerokość pasów nie odpowiada potencjałowi.',sub='Góra piramidy daje 60% naszej sprzedaży, IS tylko 7%')
tot_s=600744454
SS={'STR':120305847,'KN':122399942,'PUB':28811202,'INT':91943807,'MM':59887682,'FS':116699774,'IS':40449795}
def ps(k): return f"{100*SS[k]/tot_s:.1f}".replace('.',',')+'%'
COL={'IS':RGBColor(0xD6,0xD6,0xEE),'FS':RGBColor(0xAE,0xAF,0xDA),'MM':RGBColor(0x80,0x81,0xC2),'KN':RGBColor(0x4E,0x4F,0xA3),'STR':PURPLE,'PUB':RGBColor(0x9A,0xC3,0x1C),'INT':RGBColor(0xFF,0x80,0x2D)}
PX,PY,PW,PH=0.35,1.66,3.35,2.75; U=PH/7; TOPW=1.35
def hw(y): return (TOPW+(PW-TOPW)*y/PH)/2
cx=PX+PW/2
def L(y): return cx-hw(y)
def Rr(y): return cx+hw(y)
def Xf(y,f): return L(y)+f*2*hw(y)
def poly(pts,col,name):
    fb=s4.shapes.build_freeform(Inches(pts[0][0]),Inches(pts[0][1]),scale=1.0)
    fb.add_line_segments([(Inches(a),Inches(b)) for a,b in pts[1:]],close=True)
    shp=fb.convert_to_shape(); shp.name=name
    shp.fill.solid(); shp.fill.fore_color.rgb=col; shp.line.color.rgb=WHITE; shp.line.width=Pt(1.5)
    return shp
f1,f2=0.46,0.70
y0=PY; ym=PY+2*U; y1=PY+4*U
def yy(v): return v-PY
def P(y,f): return (Xf(yy(y),f),y)
poly([P(y0,0),P(y0,f1),P(ym,f1),P(ym,0)],COL['STR'],'Strategic')
poly([P(ym,0),P(ym,f1),P(y1,f1),P(y1,0)],COL['KN'],'K&N')
poly([P(y0,f1),P(y0,f2),P(y1,f2),P(y1,f1)],COL['PUB'],'Public')
poly([P(y0,f2),P(y0,1),P(y1,1),P(y1,f2)],COL['INT'],'International')
for i,k in enumerate(['MM','FS','IS']):
    a=PY+(4+i)*U; b=a+U
    poly([P(a,0),P(a,1),P(b,1),P(b,0)],COL[k],k)
def lab(xa,xb,y,lines,color,size=9):
    tb=s4.shapes.add_textbox(Inches(xa),Inches(y),Inches(xb-xa),Inches(0.4)); tf=tb.text_frame
    tf.margin_left=tf.margin_right=tf.margin_top=tf.margin_bottom=0; tf.word_wrap=False
    for i,(t,sz) in enumerate(lines):
        p=tf.paragraphs[0] if i==0 else tf.add_paragraph(); p.alignment=PP_ALIGN.CENTER
        r=p.add_run(); r.text=t; r.font.size=Pt(sz); r.font.bold=True; r.font.color.rgb=color
    tb.name='Etykieta '+lines[0][0]
def midx(y,a,b): return (Xf(yy(y),a)+Xf(yy(y),b))/2
yS=PY+0.55*U; xs=midx(PY+U,0,f1); lab(xs-0.5,xs+0.5,yS,[('Strategic',9),(ps('STR'),10)],WHITE)
yK=PY+2.55*U; xk=midx(PY+3*U,0,f1); lab(xk-0.5,xk+0.5,yK,[('K&N',9),(ps('KN'),10)],WHITE)
xp=midx(PY+3*U,f1,f2); lab(xp-0.4,xp+0.4,yK,[('Public',8),(ps('PUB'),10)],INK)
xi=midx(PY+3*U,f2,1); lab(xi-0.5,xi+0.5,yK,[('International',7),(ps('INT'),10)],INK)
for i,(k,nm) in enumerate([('MM','MM'),('FS','FS'),('IS','IS')]):
    y=PY+(4+i)*U+U/2-0.09; lab(cx-0.8,cx+0.8,y,[(f'{nm} · {ps(k)}',10)],WHITE if k=='MM' else INK)
text(s4,PX,1.36,PW,0.25,[('Na piramidzie: % naszej sprzedaży',True),(' (600,7 mln zł; Inne 3,4%)',False)],size=8,color=INK)
T=[('STR','Strategic','4001+',80,110,113,432.9,120.3),('INT','International','klienci DB',189,225,225,297.9,91.9),('PUB','Public','501+',90,390,609,698.3,28.8),
('KN','K&N','501–4000',665,1158,1481,889.4,122.4),('MM','MM','201–500',1614,4939,5598,906.5,59.9),('FS','FS','41–200',9703,20911,42618,1560.3,116.7),('IS','IS','1–40',12947,92798,2578736,3581.4,40.4)]
exact={'STR':120305847,'INT':91943807,'PUB':28811202,'KN':122399942,'MM':59887682,'FS':116699774,'IS':40449795}
def f1d(v): return f"{v:,.1f}".replace(',',' ').replace('.',',').replace(' ',NBSP)
rows=[[H('Linia',PP_ALIGN.LEFT),H('Przedział',PP_ALIGN.LEFT),H('Aktywni'),H('Portfel'),H('Firmy\nrynek'),H('Potencjał\nmln zł'),H('Sprzedaż\nmln zł'),H('Udział\nwart.'),H('Pene-\ntracja')]]
for k,nm,pz,a,pf,frm,pot,sp in T:
    rows.append([{'t':nm,'align':PP_ALIGN.LEFT,'bold':True,'fill':COL[k],'color':WHITE if k in ('STR','KN','MM') else INK},{'t':pz,'align':PP_ALIGN.LEFT,'color':MUTED},n(a),n(pf),n(frm),f1d(pot),f1d(sp),
                 {'t':pc(exact[k],pot*1e6),'bold':True},{'t':pc(a,frm,1 if a/frm>=0.01 else 2),'bold':True}])
rows.append([{'t':'Razem','align':PP_ALIGN.LEFT,'bold':True,'fill':NEUTRAL},{'t':'z Inne','align':PP_ALIGN.LEFT,'color':MUTED,'fill':NEUTRAL}]+[{'t':v,'bold':True,'fill':NEUTRAL} for v in [n(25644),n(141931),n(2650780),'8'+NBSP+'366,7','600,7','7,2%',pc(25644,2650780,2)]])
table(s4,3.95,1.36,[0.8,0.62,0.58,0.56,0.68,0.6,0.64,0.47,0.5],rows,rh=0.32,size=8,name='Tabela piramida')
text(s4,0.35,4.52,6.9,0.6,'Aktywni = grupy TOP_LEVEL ze sprzedażą w 12 mies.; Portfel = grupy w linii (bez Kwarantanny); Firmy rynek = portfel + firmy z Kwarantanny i niezarejestrowane w przedziale linii (do GUS). Udział wart. = sprzedaż ÷ potencjał (pracujący × 592 zł). Penetracja = aktywni ÷ firmy rynek. Szerokość pasów nie odpowiada potencjałowi.',size=7,name='Przypis')

# ================= SLAJDY 5-6 z D43 =================
rows43=[l.split('\t') for l in open(W+'d43.tsv').read().strip().split('\n')]
D={r[0]:list(map(int,r[1:])) for r in rows43}
cls=['1 0-9 JDG','2 0-9 POZOSTALE','3 10-49','4 50-249','5 250-999','6 1000+']
labk={'1 0-9 JDG':'0–9 JDG','2 0-9 POZOSTALE':'0–9 inne','3 10-49':'10–49','4 50-249':'50–249','5 250-999':'250–999','6 1000+':'1000+','7 PUBLIC':'Public','8 BRAK KLASY':'Brak klasy'}
LN=['IS','FS','MM','K&N','Strate-\ngic','Inter-\nnat.','Public\n(CA)','Inne']
# --- slajd 5: piramida GUS x BL ---
At=[sum(D[c][i] for c in cls) for i in range(8)]
rows=[[H('Klasa\nGUS',PP_ALIGN.LEFT),H('Firmy'),H('Pracujący')]+[H(x,PP_ALIGN.CENTER) for x in LN]+[H('Portfolio\nNIP'),H('Aktywne\nNIP'),H('% portf.'),H('% aktyw.'),H('Kartoteka\nbez portf.')]]
GUSF={'1 0-9 JDG':2011954,'2 0-9 POZOSTALE':767327,'3 10-49':95785,'4 50-249':17245,'7 PUBLIC':62256}
GUSP={'3 10-49':2115291,'4 50-249':1878732,'5 250-999':1655497,'6 1000+':1968204,'7 PUBLIC':2805762}
for k in labk:
    v=D[k]; row=[{'t':labk[k],'align':PP_ALIGN.LEFT,'bold':True}]
    if k=='1 0-9 JDG': row+=[{'t':n(2011954),'italic':True},{'t':'3'+NBSP+'709'+NBSP+'518\n(0–9)','span':(2,1)}]
    elif k=='2 0-9 POZOSTALE': row+=[{'t':n(767327),'italic':True},None]
    elif k=='5 250-999': row+=[{'t':'4'+NBSP+'170\n(250+)','span':(2,1)},n(GUSP[k])]
    elif k=='6 1000+': row+=[None,n(GUSP[k])]
    elif k=='8 BRAK KLASY': row+=['–','–']
    else: row+=[n(GUSF[k]),n(GUSP[k])]
    for i in range(8):
        if k in ('7 PUBLIC','8 BRAK KLASY'): row.append({'t':n(v[i]),'align':PP_ALIGN.CENTER,'fill':NEUTRAL})
        else:
            hi=hidx(100*v[i]/At[i] if At[i] else 0); row.append({'t':n(v[i]),'align':PP_ALIGN.CENTER,'fill':HEAT[hi],'color':WHITE if hi>=4 else INK})
    row+=[{'t':n(v[17]),'bold':True},{'t':n(v[8]),'bold':True}]
    if k in GUSF: row+=[pc(v[17],GUSF[k],2 if GUSF[k]>500000 else 1),pc(v[8],GUSF[k],2 if GUSF[k]>500000 else 1)]
    elif k=='5 250-999':
        pp=D['5 250-999'][17]+D['6 1000+'][17]; aa=D['5 250-999'][8]+D['6 1000+'][8]
        row+=[{'t':pc(pp,4170)+'\n(250+)','span':(2,1)},{'t':pc(aa,4170)+'\n(250+)','span':(2,1)}]
    elif k=='6 1000+': row+=[None,None]
    else: row+=['–','–']
    row+=[n(v[18])]
    rows.append(row)
tt=lambda i: sum(D[k][i] for k in labk)
rows.append([{'t':'Razem','align':PP_ALIGN.LEFT,'bold':True,'fill':NEUTRAL},{'t':n(2958737),'bold':True,'fill':NEUTRAL},{'t':n(14133004),'bold':True,'fill':NEUTRAL}]+
            [{'t':n(tt(i)),'bold':True,'align':PP_ALIGN.CENTER,'fill':NEUTRAL} for i in range(8)]+
            [{'t':'–','fill':NEUTRAL},{'t':n(tt(8)),'bold':True,'fill':NEUTRAL},{'t':pc(tt(17),2958737),'bold':True,'fill':NEUTRAL},{'t':pc(tt(8),2958737),'bold':True,'fill':NEUTRAL},{'t':n(tt(18)),'bold':True,'fill':NEUTRAL}])
rows.append([{'t':'Portfolio','align':PP_ALIGN.LEFT,'color':MUTED},{'t':'–','color':MUTED},{'t':'–','color':MUTED}]+[{'t':n(tt(9+i)),'align':PP_ALIGN.CENTER,'color':MUTED,'bold':True} for i in range(8)]+[{'t':n(tt(17)),'bold':True,'color':MUTED}]+[{'t':'–','color':MUTED}]*4)
s5=new_slide('Piramida GUS × biznes linie',
 'Wersja 2 slajdu 1, liczona według reguł slajdu 3: NIP w linii lidera swojej grupy TOP_LEVEL, NIP z kilkoma płatnikami raz (w grupie z biznes linii), NIP z SOLDTO w Kwarantannie w grupie lidera z innego regionu = portfolio tej grupy. Rynek GUS bez zmian; 0–9 podzielone na JDG i resztę wg REGON (72,4%), kursywa = szacunek.\n\nWiersz Portfolio daje w każdej linii tyle NIP-ów, ile mają grupy tej linii na slajdzie 3. W portfolio mamy 49% firm 10–49, 72% firm 50–249 i 92% firm 250+; kupuje od nas 6%, 30% i 45%.\n\nKolor: udział NIP-ów linii w klasach 0–9…1000+ (Public i brak klasy bez koloru).',sub='Mamy w portfolio 49–92% firm 10+ z GUS, kupuje od nas 6–45%')
table(s5,0.35,1.34,[0.62,0.6,0.62,0.44,0.44,0.42,0.44,0.42,0.42,0.42,0.42,0.56,0.52,0.5,0.5,0.56],rows,rh=0.265,size=7,name='Tabela piramida GUS')
text(s5,0.35,4.36+0.18,6.9,0.62,'Linia NIP-u = region lidera grupy TOP_LEVEL; NIP z kilkoma płatnikami raz. Rynek 0–9 podzielony wg REGON (72,4% JDG) – kursywa = szacunek. Klasa: DB_BAZA. Portfolio = NIP w grupie poza Kwarantanną lub aktywny; Aktywne = sprzedaż > 0 w 12 mies.; Kartoteka bez portfolio = NIP aktywny w T_CEIDG_GUS bez konta. Kolor: udział NIP-ów linii (klasy 0–9…1000+). Inne = Other SMB, Other CA, Kwarantanna.',size=7,name='Przypis')
# --- slajd 6: potencjal x BL ---
pot={'0-9':3709518*592,'3 10-49':2115291*592,'4 50-249':1878732*592,'5 250-999':1655497*592,'6 1000+':1968204*592,'7 PUBLIC':2805762*592}
St=[sum(D[c][19+i] for c in cls) for i in range(8)]
known=sum(D[c][27] for c in cls); fac=(known+D['8 BRAK KLASY'][27])/known
s09=D['1 0-9 JDG'][27]+D['2 0-9 POZOSTALE'][27]
rows=[[H('Klasa\nGUS',PP_ALIGN.LEFT),H('Pracujący'),H('Potencjał\nmln zł')]+[H(x,PP_ALIGN.CENTER) for x in LN]+[H('Sprzedaż\nmln zł'),H('Udział'),H('z rozł.\nbraku kl.')]]
def sc(k):
    out=[]
    for i in range(8):
        if k not in cls: out.append({'t':m(D[k][19+i]),'align':PP_ALIGN.CENTER,'fill':NEUTRAL})
        else:
            hi=hidx(100*D[k][19+i]/St[i] if St[i] else 0); out.append({'t':m(D[k][19+i]),'align':PP_ALIGN.CENTER,'fill':HEAT[hi],'color':WHITE if hi>=4 else INK})
    return out
for k in ['1 0-9 JDG','2 0-9 POZOSTALE','3 10-49','4 50-249','5 250-999','6 1000+','7 PUBLIC','8 BRAK KLASY']:
    v=D[k]; row=[{'t':labk[k],'align':PP_ALIGN.LEFT,'bold':True}]
    if k=='1 0-9 JDG':
        row+=[{'t':'3'+NBSP+'709'+NBSP+'518\n(0–9)','span':(2,1)},{'t':m(pot['0-9'],0)+'\n(0–9)','span':(2,1)}]+sc(k)+[{'t':m(v[27]),'bold':True},{'t':pc(s09,pot['0-9'])+'\n(0–9)','span':(2,1),'bold':True},{'t':pc(s09*fac,pot['0-9'])+'\n(0–9)','span':(2,1)}]
    elif k=='2 0-9 POZOSTALE': row+=[None,None]+sc(k)+[{'t':m(v[27]),'bold':True},None,None]
    elif k=='8 BRAK KLASY': row+=['–','–']+sc(k)+[{'t':m(v[27]),'bold':True},'–','–']
    else:
        pr={'3 10-49':2115291,'4 50-249':1878732,'5 250-999':1655497,'6 1000+':1968204,'7 PUBLIC':2805762}[k]
        adj=pc(v[27],pot[k]) if k=='7 PUBLIC' else pc(v[27]*fac,pot[k])
        row+=[n(pr),m(pot[k],0)]+sc(k)+[{'t':m(v[27]),'bold':True},{'t':pc(v[27],pot[k]),'bold':True},adj]
    rows.append(row)
bn=[D['9 BEZ NIP'][19+i]+D['9 NIP SPOZA LISTY'][19+i] for i in range(8)]; bns=D['9 BEZ NIP'][27]+D['9 NIP SPOZA LISTY'][27]
rows.append([{'t':'Bez NIP','align':PP_ALIGN.LEFT,'bold':True},'–','–']+[{'t':m(x),'align':PP_ALIGN.CENTER,'fill':NEUTRAL} for x in bn]+[{'t':m(bns),'bold':True},'–','–'])
FA=sum(v[27] for v in D.values()); tp=sum(pot.values()); Sall=[sum(v[19+i] for v in D.values()) for i in range(8)]
rows.append([{'t':'Razem','align':PP_ALIGN.LEFT,'bold':True,'fill':NEUTRAL},{'t':n(14133004),'bold':True,'fill':NEUTRAL},{'t':m(tp,0),'bold':True,'fill':NEUTRAL}]+[{'t':m(x),'bold':True,'align':PP_ALIGN.CENTER,'fill':NEUTRAL} for x in Sall]+[{'t':m(FA),'bold':True,'fill':NEUTRAL},{'t':pc(FA,tp),'bold':True,'fill':NEUTRAL},{'t':pc(FA,tp),'bold':True,'fill':NEUTRAL}])
s6=new_slide('Potencjał wg klas GUS',
 'Wersja 2 slajdu 2. Klasy, rynek i potencjał bez zmian; sprzedaż liczymy tam, gdzie się odbyła – wg regionu SOLDTO z faktury, jak na slajdzie 3. Razem w każdej linii = sprzedaż linii ze slajdu 3, razem 600,7 mln zł.\n\nUdział w klasach: 0,7% w 0–9, 3,6% w 10–49, 8,7% w 50–249, 12,4% w 250–999, 16,5% w 1000+, Public 2,1%.\n\nGdzie sprzedają linie: IS – połowa w 10–49, jedna trzecia w JDG; FS – 62% w 50–249, 31% w 10–49; MM – po połowie w 50–249 i 250–999; K&N – 48% w 250–999 i 34% w 1000+; Strategic – 79% w 1000+; International – 62% w 1000+. FS ma 37% sprzedaży w firmach do 49 osób, K&N 18% w firmach do 249 osób.',sub='Udział od 0,7% w firmach 0–9 do 16,5% w 1000+; razem 7,2%')
table(s6,0.35,1.34,[0.62,0.66,0.62,0.52,0.52,0.52,0.52,0.52,0.52,0.52,0.52,0.62,0.55,0.6],rows,rh=0.265,size=7,name='Tabela potencjal')
text(s6,0.35,4.5,6.9,0.55,f'Sprzedaż = wszystkie faktury 12 mies. wg regionu SOLDTO z faktury; Razem w linii = sprzedaż linii ze slajdu 3. Klasa = zatrudnienie NIP-u kupującego (DB_BAZA). Potencjał = pracujący GUS × 592 zł. „z rozł. braku kl.” rozkłada sprzedaż bez klasy (93 mln zł) proporcjonalnie (×{f"{fac:.2f}".replace(".",",")}). Kolor: udział klasy w sprzedaży linii.',size=7,name='Przypis')

prs.save(W+'pptx/Piramida_klientow_Lyreco.pptx')
print('ok')
