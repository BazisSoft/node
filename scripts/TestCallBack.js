cb = NewCallBackClass();
system.log('callback class created');
cb.OnClick = function (){
	system.log('callback OnClick called');
}
system.log('callback func set');
system.log('start to make Click');
cb.MakeClick();
system.log('Click was made');