import {readFileSync} from 'node:fs';
export const factbook=JSON.parse(readFileSync(new URL('./catalog/protected-areas.json',import.meta.url),'utf8'));
const source='https://ugandawildlife.org/wp-content/uploads/2024/03/UWA-Conservation-Tariff-July-2024-June-2026.pdf';
export const safetyTips=[
  {id:'safe-route',name:'Share your plans',category:'Everyday travel',description:'Tell a trusted contact your route and expected return. Keep emergency contacts and a charged phone available.',tags:'general',sourceUrl:''},
  {id:'safe-wildlife',name:'Give wildlife space',category:'Wildlife',description:'Stay in your vehicle unless your guide says it is safe to leave. Do not feed, approach or provoke wildlife.',tags:'safari wildlife game drive park',sourceUrl:source},
  {id:'safe-trekking',name:'Follow your ranger',category:'Trekking',description:'Stay with your ranger-led group and follow the briefing. Keep to designated routes and tell your guide if you feel unwell.',tags:'gorilla chimpanzee trek hike forest bwindi mgahinga kibale',sourceUrl:source},
  {id:'safe-nature',name:'Leave the habitat intact',category:'Conservation',description:'Take litter away with you. Do not collect plants or disturb animals. Respect park access restrictions.',tags:'park safari forest hike wildlife',sourceUrl:source},
  {id:'safe-night',name:'Plan evening travel',category:'After dark',description:'Arrange trusted transport in advance. Choose staffed, well-lit places and avoid isolated routes after dark.',tags:'night evening',sourceUrl:''},
  {id:'safe-road',name:'Choose trusted transport',category:'Transport',description:'Confirm your driver and destination before departure. Use available seat belts and keep your valuables secure.',tags:'city road transport kampala entebbe jinja',sourceUrl:''},
  {id:'safe-water',name:'Check water conditions',category:'Water activities',description:'Use a reputable operator, wear the supplied flotation equipment and follow local instructions. Do not enter unfamiliar water alone.',tags:'water boat rafting river lake jinja',sourceUrl:''},
  {id:'safe-weather',name:'Prepare for changing conditions',category:'Outdoors',description:'Check local weather and your guide’s advice. Carry water, suitable footwear, sun protection and a rain layer.',tags:'hike trek mountain forest outdoor rwenzori elgon',sourceUrl:''},
];
export function seedCatalog(db) {
  const get=db.prepare('SELECT 1 FROM records WHERE collection=? AND id=?');
  const put=db.prepare('INSERT INTO records(collection,id,data) VALUES(?,?,?)');
  const now=new Date().toISOString();
  db.exec('BEGIN');
  try {
    for(const [collection,records] of [['parks',factbook.records],['tips',safetyTips]]) for(const record of records) {
      if(!get.get(collection,record.id)) put.run(collection,record.id,JSON.stringify({status:'Active',createdAt:now,updatedAt:now,...record}));
    }
    db.exec('COMMIT');
  }catch(error){db.exec('ROLLBACK');throw error;}
}
