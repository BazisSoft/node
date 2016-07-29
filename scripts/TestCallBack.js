cb = NewCallBackClass();
cb.OnClick = function (){
	system.log('Value changing');
};
system.log(cb.Value);
system.log('Setting value');
cb.Value = 40;
system.log('value was set');
system.log(cb.Value);