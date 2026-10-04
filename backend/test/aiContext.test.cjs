const {test}=require('node:test');
const assert=require('node:assert/strict');
const {nutritionContext}=require('../lib/aiContext');
const {validateOutput}=require('../lib/aiValidation');
const {validateMacroAdjustment}=require('../lib/macroSafety');
const base={profile:{age:24},targets:{calories:2500,protein:120,carbs:300,fat:70},sevenDay:{daysLogged:7}};
test('context validation works without an ambient Node Buffer in Edge',()=>{
  const previous=global.Buffer;
  try {global.Buffer=undefined;assert.equal(nutritionContext('chat',base).targets.calories,2500);}
  finally {global.Buffer=previous;}
});
test('context boundary strips identity and bounds recent memory',()=>{
  const input={profile:{age:24,email:'private',uid:'private',password:'private',allergies:['peanut']},
    authToken:'private',activity:{source:'healthConnect',steps:20,token:'private'},
    recentMeals:Array.from({length:20},()=>({name:'Dal',protein:5,uid:'private'})),
    recentScans:Array.from({length:20},()=>({name:'Snack',email:'private'}))};
  const result=nutritionContext('chat',input);
  assert.ok(!JSON.stringify(result).includes('private'));
  assert.equal(result.recentMeals.length,8); assert.equal(result.recentScans.length,5);
  assert.equal(nutritionContext('meal',input).profile.age,undefined);
  assert.equal(nutritionContext('analysis',input).recentMeals,undefined);
});
test('unknown totals remain unknown and malformed numeric context is rejected',()=>{
  assert.equal(nutritionContext('chat',{today:{protein:null}}).today.protein,null);
  assert.throws(()=>nutritionContext('chat',{today:{protein:-1}}));
  assert.throws(()=>nutritionContext('chat',{today:{remaining:{protein:'20'}}}));
});
test('quick replies require short distinct complete output',()=>{
  assert.deepEqual(validateOutput('quickReplies',{replies:['What can I eat?','How much protein?']}),{replies:['What can I eat?','How much protein?']});
  for(const replies of [[],['One'],['Same','same'],['x'.repeat(101),'Other']]) assert.throws(()=>validateOutput('quickReplies',{replies}));
});
test('recalibration rejects excessive jumps, negative and too-low targets',()=>{
  for(const calories of [1400,2800,-1,Infinity]) assert.throws(()=>validateMacroAdjustment({...base.targets,calories,explanation:'test'},base));
  assert.equal(validateMacroAdjustment({...base.targets,calories:2600,explanation:'test'},base).calories,2600);
  assert.throws(()=>validateMacroAdjustment({...base.targets,calories:2600,explanation:'test'},base,2));
});
test('zero or one logged day retains baseline without a weight inference',()=>{
  for(const daysLogged of [0,1,2]) {
    const result=validateMacroAdjustment({...base.targets,calories:2000}, {...base,sevenDay:{daysLogged}});
    assert.equal(result.calories,2500);assert.match(result.explanation,/Low confidence/);
  }
  assert.throws(()=>validateMacroAdjustment(base.targets,{...base,profile:{age:16}}));
});
