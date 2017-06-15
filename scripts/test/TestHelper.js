obj = NewSomeObject();
obj.Value = 10;
obj2 = NewSomeChild();
obj2.Value = 5;
console.assert(obj.ValueSqr() === 100);
console.assert(obj2.ValueSqr() === 25);
console.assert(obj2.ValueX2()) === 10;