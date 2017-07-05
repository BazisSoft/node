attr_obj = NewAttrObject();
let error = false;
attr_obj.GetNumber();
try{
attr_obj.GetForbiddenNumber();
}
catch(e){
    error = true;
}
console.assert(error)