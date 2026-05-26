import { expect, test } from '@jest/globals';

// Example simple unit test

test('satoshis-to-BTC conversion works', () => {
  const toBtc = (sats) => sats / 1e8;
  expect(toBtc(100000000)).toBe(1);
  expect(toBtc(50000000)).toBe(0.5);
});

test('random reward in valid range', () => {
  function getReward() {
    let r = Math.floor(Math.random() * 15000) + 50;
    if(Math.random() < 0.04){
      r = Math.floor(Math.random() * 100000) + 25000;
    }
    return r;
  }
  for(let i=0; i<1000; i++) {
    const v = getReward();
    expect(v).toBeGreaterThanOrEqual(50);
    expect(v).toBeLessThanOrEqual(125000);
  }
});
