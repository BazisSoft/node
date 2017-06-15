let error = false;
try{
    attr_obj = NewForbiddenObject();
}
catch(e){
    error = true;
}
console.assert(error)
