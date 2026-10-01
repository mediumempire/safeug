"""Read the supplied factbook without changing it; preserve its qualifications."""
import argparse, hashlib, json, re
from pathlib import Path
import openpyxl

p=argparse.ArgumentParser()
p.add_argument('workbook',type=Path)
args=p.parse_args()
w=openpyxl.load_workbook(args.workbook,data_only=True,read_only=True)
keys=['number','name','aliases','category','legalClass','iucn','gazetted','region','districts','coordinates','areaKm2','areaHectares','areaNotes','habitat','activities','mammals','birds','floraFauna','designations','governance','tourism','rangerNotes','threats','notes']
records=[]
for sheet in ['03_National_Parks','04_Wildlife_Reserves','05_Community_WMAs','06_Wildlife_Sanctuaries']:
    for row_number,row in enumerate(w[sheet].iter_rows(values_only=True),1):
        if not isinstance(row[0],(int,float)) or not row[1]: continue
        r=dict(zip(keys,row))
        r.pop('number')
        r['categoryGroup']={'03_National_Parks':'National parks','04_Wildlife_Reserves':'Wildlife reserves','05_Community_WMAs':'Community areas','06_Wildlife_Sanctuaries':'Sanctuaries'}[sheet]
        r['referenceOnly']=r['name']=='Other listed sanctuary names in circulation'
        r.update(id='uwa-'+re.sub('[^a-z0-9]+','-',r['name'].lower()).strip('-'),status='Active',area=r['region'],description=r['habitat'],sourceWorkbook=args.workbook.name,sourceSheet=sheet,sourceRow=row_number,sourceKind='Supplied factbook; indicative figures')
        coordinate=re.fullmatch(r'([\d.]+)\s*([NS]),\s*([\d.]+)\s*([EW])',str(r['coordinates']))
        if coordinate:
            a,b,c,d=coordinate.groups()
            r.update(latitude=float(a)*(-1 if b=='S' else 1),longitude=float(c)*(-1 if d=='W' else 1),locationSource='factbook-approximate')
        records.append(r)
notes=[{'topic':r[0],'note':r[1]} for r in w['08_Data_Notes'].iter_rows(min_row=5,values_only=True) if r[0] and r[1]]
out=Path(__file__).resolve().parents[1]/'local/catalog'
out.mkdir(parents=True,exist_ok=True)
(out/'protected-areas.json').write_text(json.dumps({'source':args.workbook.name,'sha256':hashlib.sha256(args.workbook.read_bytes()).hexdigest(),'notes':notes,'records':records},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Imported',len(records),'records; categories:',{c:sum(r['category']==c for r in records) for c in sorted({r['category'] for r in records})})
