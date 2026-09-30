// Provider contracts are deliberately disabled until UWA approves the endpoints.
export function integrationStatus() {
  return [
    {id:'dispatch',name:'Emergency dispatch',status:process.env.SAFEUG_DISPATCH_URL?'Configured - not verified':'Awaiting UWA requirements',requirements:'HTTPS gateway, authentication, idempotency support, response and receipt contract'},
    {id:'sms',name:'SMS gateway',status:'Awaiting UWA requirements',requirements:'Provider, sender ID, consent rules, recipient routing, delivery receipts'},
    {id:'radio',name:'Radio / off-grid gateway',status:'Awaiting UWA requirements',requirements:'Device model, permitted frequencies, gateway protocol, pairing and acknowledgements'},
    {id:'satellite',name:'Satellite service',status:'Awaiting UWA requirements',requirements:'Terminal model, subscription, API specification, payload limits and delivery receipts'},
    {id:'earthranger',name:'EarthRanger',status:'Awaiting UWA requirements',requirements:'Server URL, OAuth access, event types, subject groups and attachment permissions'},
    {id:'translation',name:'Voice translation',status:process.env.SAFEUG_TRANSLATE_URL?'Configured - not verified':'Translation engine not configured',requirements:'LibreTranslate-compatible endpoint with installed languages; speech voices depend on device'},
  ];
}
