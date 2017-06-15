cb = NewCallBackClass();
let callbackCalled = false;
cb.Value = 23;
cb.OnValueChange = function (){
	callbackCalled = true;
};
console.assert(!callbackCalled);
cb.Value = 40;
console.assert(callbackCalled);