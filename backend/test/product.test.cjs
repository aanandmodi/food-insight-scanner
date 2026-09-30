const { test } = require('node:test');
const assert = require('node:assert/strict');
const { normalizeOpenFoodFacts } = require('../lib/productNormalizer');
const { validateOutput, profileData } = require('../lib/aiValidation');

for (const [grams, milligrams] of [[0.3,300], [0.6,600], [0.75,750], [1.2,1200]]) {
  test(`${grams} g sodium becomes ${milligrams} mg through canonical and compatibility keys`, () => {
    const product = normalizeOpenFoodFacts({nutriments: {sodium_100g: grams}}, '12345678');
    assert.equal(product.nutrition.sodiumMgPer100g, milligrams);
    assert.equal(product.nutrition.sodium, milligrams);
    assert.equal(product.schemaVersion, 2);
  });
}
test('normalizes nutrition, energy fallback, declared zeros, allergens and traces', () => {
  const product = normalizeOpenFoodFacts({product_name:'Test', ingredients_text:'whey, rice',
    allergens_tags:['en:milk'], traces_tags:['en:peanuts'], nutriments:{energy_100g:418.4,
      sugars_100g:0, proteins_100g:'10', carbohydrates_100g:12, fat_100g:2, fiber_100g:3}}, '12345678');
  assert.equal(product.nutrition.energyKcalPer100g,100);
  assert.equal(product.nutrition.sugarGPer100g,0);
  assert.equal(product.nutrition.proteinGPer100g,10);
  assert.equal(product.nutrition.sodiumMgPer100g,null);
  assert.deepEqual(product.allergens,['milk']);
  assert.deepEqual(product.traces,['peanuts']);
});
test('missing and invalid nutrients stay unknown', () => {
  const product = normalizeOpenFoodFacts({nutriments:{sugars_100g:-5,sodium_100g:'unknown'}}, '12345678');
  for (const value of Object.values(product.nutrition)) assert.equal(value,null);
});
test('impossible per-100g values and NOVA categories stay unknown', () => {
  const product = normalizeOpenFoodFacts({nutriments:{sugars_100g:180,
    'energy-kcal_100g':1800,sodium_100g:120},nova_group:9}, '12345678');
  assert.equal(product.nutrition.sugarGPer100g,null);
  assert.equal(product.nutrition.energyKcalPer100g,null);
  assert.equal(product.nutrition.sodiumMgPer100g,null);
  assert.equal(product.novaGroup,null);
});
test('model output cannot return negative, infinite or excessive nutrients', () => {
  const base = {name:'Dal', calories:300,protein:10,carbs:40,fat:8,sugar:2};
  for (const calories of [-1,Infinity,50001,'100']) assert.throws(() => validateOutput('meal',{...base,calories}));
  assert.equal(validateOutput('meal',base).name,'Dal');
  assert.throws(() => validateOutput('meal',{...base,protein:undefined}));
  assert.throws(() => validateOutput('chat',{reply:''}));
});
test('profile validation bounds arrays and excludes identity and medical history', () => {
  const profile = profileData({country:'India',region:'Gujarati',allergies:['Milk'],name:'Private',email:'private@example.org',diseases:['Private']});
  assert.deepEqual(profile,{country:'India',region:'Gujarati',allergies:['Milk']});
  assert.throws(() => profileData({allergies:Array(31).fill('milk')}));
  assert.throws(() => profileData({allergies:[{nested:'value'}]}));
});
test('plans require unique meal types and ingredients; totals are recomputed', () => {
  const meals = ['Breakfast','Lunch','Dinner','Snack'].map(type => ({type,name:'Dal',description:'Cook lentils',ingredients:['lentils'],calories:300,protein:10,carbs:40,fat:8,sugar:2}));
  const plan = validateOutput('plan',{summary:'General suggestions',meals,totalCalories:999});
  assert.equal(plan.totalCalories,1200);
  assert.throws(() => validateOutput('plan',{summary:'Bad',meals:meals.map(m=>({...m,type:'Breakfast'}))}));
  assert.throws(() => validateOutput('plan',{summary:'Bad',meals:meals.map(m=>({...m,ingredients:[]}))}));
});
