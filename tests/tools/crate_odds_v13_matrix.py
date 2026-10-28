"""Transcribe the user's CSV exactly; decimal evidence, no production approval."""
import csv,io,json
from decimal import Decimal
from pathlib import Path
root=Path(__file__).resolve().parents[2]
attachment=Path(r'C:\Users\rataatrevida\.codex\attachments\d85577e4-58bd-458f-84ab-1de46637b2c9\Texto pegado.txt')
raw=attachment.read_text(encoding='utf-8-sig').split('```csv')[1].split('```')[0].strip()
rows=list(csv.reader(io.StringIO(raw)));order=rows[0][1:]
assert len(set(order))==12 and [r[0] for r in rows[1:]]==order
lines=['--!nonstrict','-- Initial balance under review. This manifest never approves or enables commerce.',
 'local Matrix={VariationOrder={'+','.join('"'+v+'"'for v in order)+'},Rows={']
evidence=[]
for row in rows[1:]:
 values=list(map(Decimal,row[1:]));assert len(values)==12 and all(v>=0 and v.is_finite()for v in values)and sum(values)==Decimal(100)
 lines.append(' ["'+row[0]+'"]={'+','.join(row[1:])+'},')
 evidence.append(dict(CrateId=row[0],Percentages=row[1:],DecimalSum=str(sum(values))))
lines+=['}}','function Matrix.WeightsFor(id)',' local row=assert(Matrix.Rows[id],"UnknownMatrixCrate:"..tostring(id))',
 ' local weights={} for i,vid in ipairs(Matrix.VariationOrder)do weights[vid]=row[i]end',' return weights','end','return Matrix']
(root/'src/shared/SlapCrates/InitialOdds.luau').write_text('\n'.join(lines)+'\n',encoding='utf-8')
(root/'tests/CrateOddsV13.matrix.csv').write_text(raw+'\n',encoding='utf-8')
(root/'tests/CrateOddsV13.decimal.json').write_text(json.dumps(dict(VariationOrder=order,Rows=evidence),indent=2),encoding='utf-8')
