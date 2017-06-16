let error = '';
try{
    let intf = NewCOMObject('InternetExplorer.Application');
    intf.Quit();
}
catch(e){
    error = e.stack;
}
console.assert(!error, error);