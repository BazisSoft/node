obj = NewSomeObject();
obj.Value = 10;
obj2 = NewSomeChild();
obj2.Value = 50;
system.log(obj.ValueSqr());
system.log(obj2.ValueSqr());
system.log(obj2.ValueX2());