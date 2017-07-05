let list = NewSomeList();
let obj1 = NewSomeObject();
list.Add(obj1);
let obj2 = NewSomeObject();
list.Add(obj2);
console.assert(obj1 === list.Items[0]);
console.assert(obj2 === list[1]);