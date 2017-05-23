#pragma once

#include "v8.h"
#include "node.h"
#include "libplatform\libplatform.h"
#include <assert.h>
#include <memory>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <vector>
#include <stack>
#include <unordered_map>

#define APIENTRY __stdcall
#define BZINTF _declspec(dllexport)
#define BZDECL __cdecl
#define BZDEPRECATED _declspec(deprecated)


namespace Bv8 {

class IObject;
class IValueArray;
class IRecord;
class IValue;

class IBazisIntf {
public:
	virtual ~IBazisIntf() {};
	virtual void APIENTRY Delete() { delete this; };
	virtual int APIENTRY TestFun() { return 101; };
};

class IBaseValue : public IBazisIntf {
public:
    IBaseValue(v8::Isolate * isolate, v8::Local<v8::Value> value = v8::Local<v8::Value>());
    v8::Local<v8::Value> GetV8Value();
    void SetV8Value(v8::Local<v8::Value> value);
    v8::Isolate * Isolate();
    v8::Local<v8::Context> GetCurrentContext();
    virtual bool APIENTRY IsObject();
    virtual bool APIENTRY IsArray();
    virtual bool APIENTRY IsRecord();
    virtual bool APIENTRY IsValue();

    virtual IObject * APIENTRY AsObject();
    virtual IValueArray * APIENTRY AsArray();
    virtual IRecord * APIENTRY AsRecord();
    virtual IValue * APIENTRY AsValue();
private:
    v8::Persistent<v8::Value> v8Value;
    v8::Isolate * iso;
};

class IObject : public IBaseValue {
public:
	IObject(v8::Isolate * isolate, v8::Local<v8::Object> object);
	virtual bool APIENTRY IsDelphiObject();
	virtual void* APIENTRY GetDelphiObject();
	virtual void* APIENTRY GetDelphiClasstype();
private:
	bool isDObject = false;
};

class IFunction : public IBazisIntf {
public:
	IFunction(v8::Local<v8::Function> function, v8::Isolate * isolate);
	virtual void APIENTRY AddArgAsInt(int val);
	virtual void APIENTRY AddArgAsBool(bool val);
	virtual void APIENTRY AddArgAsString(char* val);
	virtual void APIENTRY AddArgAsNumber(double val);
	virtual void APIENTRY AddArgAsObject(void * value, void * classtype);
	virtual IValue * APIENTRY CallFunction();
private:
	v8::Isolate * iso = nullptr;
	std::vector<v8::Local<v8::Value>> argv;
	v8::Persistent<v8::Function> func;
	std::vector<char> run_string_result;
	IValue * returnVal = nullptr;
};

class IValueArray : public IBaseValue {
public:
	IValueArray(v8::Isolate * isolate, v8::Local<v8::Array> values_arr);
	IValueArray(v8::Isolate * isolate, int count);
	virtual int APIENTRY GetCount();
	virtual IBaseValue * APIENTRY GetValue(int index);
	virtual void APIENTRY SetValue(IBaseValue * value, int index);

	std::vector<v8::Local<v8::Value>> GeV8ValueVector();
	v8::Local<v8::Array> GetV8Array();
private:
	std::vector<std::unique_ptr<IBaseValue>> values;
	int length = -1;
};

class IRecord : public IBaseValue {
public:
	IRecord(v8::Isolate * isolate);
	IRecord(v8::Isolate * isolate, v8::Local<v8::Object> localObj);

	virtual void APIENTRY SetIntField(char * name, int val);
	virtual void APIENTRY SetDoubleField(char * name, double val);
	virtual void APIENTRY SetBoolField(char * name, bool val);
	virtual void APIENTRY SetStringField(char * name, char * val);
	virtual void APIENTRY SetObjectField(char * name, void * val);
    virtual void APIENTRY SetValueField(char * name, IBaseValue * val);

	virtual int APIENTRY GetIntField(char * name);
	virtual double APIENTRY GetDoubleField(char * name);
	virtual bool APIENTRY GetBoolField(char * name);
	virtual char * APIENTRY GetStringField(char * name);
	virtual void * APIENTRY GetObjectField(char * name);

    v8::Local<v8::Object> GetV8Object();
private:
    v8::Local<v8::Value> GetField(char * name);
	std::vector<char> run_string_result;
};

class IValue : public IBaseValue {
public:
    IValue(v8::Isolate * iso, v8::Local<v8::Value> val, int index);

    //show arg's classtype 
    virtual bool APIENTRY ArgIsNumber();
    virtual bool APIENTRY ArgIsInt();
    virtual bool APIENTRY ArgIsBool();
    virtual bool APIENTRY ArgIsString();
    virtual bool APIENTRY ArgIsObject();
    virtual bool APIENTRY ArgIsArray();
    virtual bool APIENTRY ArgIsV8Function();
    virtual bool APIENTRY ArgIsUndefined();

    //get arg 
    virtual double APIENTRY GetArgAsNumber();
    virtual int APIENTRY GetArgAsInt();
    virtual bool APIENTRY GetArgAsBool();
    virtual char* APIENTRY GetArgAsString();
    virtual IObject * APIENTRY GetArgAsObject();
    virtual IValueArray * APIENTRY GetArgAsArray();
    virtual IRecord * APIENTRY GetArgAsRecord();
    virtual IFunction * APIENTRY GetArgAsFunction();

    int GetIndex();
private:

    IObject * GetObjectFromString();
    std::vector<char> run_string_result;
    IObject * obj = nullptr;
    IValueArray * arr = nullptr;
    IRecord * rec = nullptr;
    IFunction * func = nullptr;
    int ind = -1;
};

class IMethodArgs : public IBazisIntf {
public:
	IMethodArgs(const v8::FunctionCallbackInfo<v8::Value>& newArgs);
	virtual void * APIENTRY GetEngine();
	virtual void * APIENTRY GetDelphiObject();
	virtual void * APIENTRY GetDelphiClasstype();
	virtual int APIENTRY GetArgsCount();

	virtual char * APIENTRY GetMethodName();

	virtual void APIENTRY SetReturnValueUndefined();
	virtual void APIENTRY SetReturnValueIFace(void * value);
	virtual void APIENTRY SetReturnValueClass(void * value, void* dClasstype);
	virtual void APIENTRY SetReturnValueInt(int val);
	virtual void APIENTRY SetReturnValueBool(bool val);
	virtual void APIENTRY SetReturnValueString(char * val);
	virtual void APIENTRY SetReturnValueDouble(double val);
    virtual void APIENTRY SetReturnValue(IBaseValue * val);

	virtual IValue * APIENTRY GetArg(int index);
	virtual void * APIENTRY GetDelphiMethod();

	virtual void APIENTRY SetError(char * errorMsg);
	std::string error = "";
private:
    v8::Isolate * iso = nullptr;
	std::vector<std::unique_ptr<IValue>> values;
	const v8::FunctionCallbackInfo<v8::Value>* args = nullptr;
	std::vector<char> run_string_result;
};

class IGetterArgs : public IBazisIntf {
public:
	IGetterArgs(const v8::PropertyCallbackInfo<v8::Value>& info, char * prop);
    IGetterArgs(const v8::PropertyCallbackInfo<v8::Value>& info, v8::Local<v8::Value> index);
	IGetterArgs(const v8::PropertyCallbackInfo<v8::Value>& info, int index);
	virtual void * APIENTRY GetEngine();
	virtual void * APIENTRY GetDelphiObject();
	virtual void * APIENTRY GetDelphiClasstype();
	virtual char * APIENTRY GetPropName();
	virtual int APIENTRY GetPropIndex();
    virtual IValue * APIENTRY GetPropIndexAsIValue();

	virtual void APIENTRY SetGetterResultUndefined();
	virtual void APIENTRY SetGetterResultIFace(void * value);
	virtual void APIENTRY SetGetterResultAsInterfaceFunction(void * intf, char * funcName);
	virtual void APIENTRY SetGetterResultDObject(void * value, void* dClasstype);
	virtual void APIENTRY SetGetterResultInt(int val);
	virtual void APIENTRY SetGetterResultBool(bool val);
	virtual void APIENTRY SetGetterResultString(char * val);
	virtual void APIENTRY SetGetterResultDouble(double val);
	virtual void APIENTRY SetGetterResultAsIndexObject(void * parentObj, void* rttiProp);
    virtual void APIENTRY SetGetterResult(IBaseValue * val);

	virtual void APIENTRY SetError(char * errorMsg);
	std::string error = "";
private:
    v8::Isolate * iso = nullptr;
	bool IsIndexedProp = false;
	std::string propName = "";
    IValue * indexValue = nullptr;
	int propInd = -1;
	const v8::PropertyCallbackInfo<v8::Value> * propinfo = nullptr;
	std::vector<char> run_string_result;
};

class ISetterArgs : public IBazisIntf {
public:
    ISetterArgs(const v8::PropertyCallbackInfo<void>& info, char * prop, v8::Local<v8::Value> newValue);
    ISetterArgs(const v8::PropertyCallbackInfo<v8::Value>& info, v8::Local<v8::Value> index, v8::Local<v8::Value> newValue);
	ISetterArgs(const v8::PropertyCallbackInfo<v8::Value>& info, int index, v8::Local<v8::Value> newValue);
	virtual void * APIENTRY GetEngine();
	virtual void * APIENTRY GetDelphiObject();
	virtual void * APIENTRY GetDelphiClasstype();
	virtual char * APIENTRY GetPropName();
	virtual int APIENTRY GetPropIndex();
    virtual IValue * APIENTRY GetPropIndexAsIValue();
	virtual IValue * APIENTRY GetValue();

	virtual void * APIENTRY GetValueAsDObject();
	virtual int APIENTRY GetValueAsInt();
	virtual bool APIENTRY GetValueAsBool();
	virtual char * APIENTRY GetValueAsString();
	virtual double APIENTRY GetValueAsDouble();

	virtual void APIENTRY SetGetterResultUndefined();
	virtual void APIENTRY SetGetterResultIFace(void * value);
	virtual void APIENTRY SetGetterResultAsInterfaceFunction(void * intf, char * funcName);
	virtual void APIENTRY SetGetterResultDObject(void * value, void* dClasstype);
	virtual void APIENTRY SetGetterResultInt(int val);
	virtual void APIENTRY SetGetterResultBool(bool val);
	virtual void APIENTRY SetGetterResultString(char * val);
	virtual void APIENTRY SetGetterResultDouble(double val);
	virtual void APIENTRY SetGetterResultAsIndexObject(void * parentObj, void* rttiProp);
    virtual void APIENTRY SetGetterResult(IBaseValue * val);

	virtual void APIENTRY SetError(char * errorMsg);
	std::string error = "";
private:
    v8::Isolate * iso = nullptr;
	bool IsIndexedProp = false;
    IValue * indexVal = nullptr;
	std::string propName = "";
	int propInd = -1;
	std::vector<char> run_string_result;
	const v8::PropertyCallbackInfo<void> * propinfo = nullptr;
	const v8::PropertyCallbackInfo<v8::Value> * indexedPropInfo = nullptr;
	v8::Local<v8::Value> newVal;
	IValue * setterVal = nullptr;
};

class IIntfSetterArgs : public IBazisIntf {
public:
	IIntfSetterArgs(const v8::PropertyCallbackInfo<v8::Value>& info, char * prop, v8::Local<v8::Value> newValue);
	virtual void * APIENTRY GetEngine();
	virtual void * APIENTRY GetDelphiObject();
	virtual char * APIENTRY GetPropName();
	virtual IValue * APIENTRY GetValue();

	virtual void * APIENTRY GetValueAsDObject();
	virtual int APIENTRY GetValueAsInt();
	virtual bool APIENTRY GetValueAsBool();
	virtual char * APIENTRY GetValueAsString();
	virtual double APIENTRY GetValueAsDouble();

	virtual void APIENTRY SetError(char * errorMsg);
	std::string error = "";
private:
	v8::Isolate * iso = nullptr;
	std::string propName = "";
	std::vector<char> run_string_result;
	const v8::PropertyCallbackInfo<v8::Value> * IntfPropInfo = nullptr;
	v8::Local<v8::Value> newVal;
	IValue * setterVal = nullptr;
};

typedef void(APIENTRY *TMethodCallBack) (IMethodArgs * args);
typedef void(APIENTRY *TGetterCallBack) (IGetterArgs * args);
typedef void(APIENTRY *TSetterCallBack) (ISetterArgs * args);
typedef void(APIENTRY *TIntfSetterCallBack) (IIntfSetterArgs * args);
typedef void(APIENTRY *TErrorMsgCallBack) (const char * errMsg, void * DEngine);

class IObjectProp : public IBazisIntf {
public:
	virtual void APIENTRY SetRead(bool Aread);;
	virtual void APIENTRY SetWrite(bool Awrite);
	virtual void APIENTRY setName(char * Aname);
	IObjectProp(std::string pName, void * pObj, bool pRead = true, bool Pwrite = true);
	IObjectProp();
	std::string name = "";
	bool read = true;
	bool write = true;
	void * obj;
};

class IObjectMethod : public IBazisIntf {
public:
	std::string name = "";
	void * call = nullptr;
};

class IDelphiEnumValue {
public:
	std::string name = "";
	int value = -1;
	IDelphiEnumValue(char * _name, int _value) { name = _name; value = _value; };
};

class IObjectTemplate : public IBazisIntf {
public:
	IObjectTemplate(std::string objclasstype, v8::Isolate * isolate);

	virtual void APIENTRY SetMethod(char * methodName, void * methodCall);
	////maybe there isn't needed propObj
	virtual void APIENTRY SetProp(char* propName, void * propObj, bool read, bool write);
	virtual void APIENTRY SetIndexedProp(char* propName, void * propObj, bool read, bool write);
	virtual void APIENTRY SetField(char* fieldName);
	virtual void APIENTRY SetEnumField(char * valuename, int value);
	virtual void APIENTRY SetHasIndexedProps(bool hasIndProps);
	virtual void APIENTRY SetParent(IObjectTemplate * parent);

	void * DClass = nullptr;
    std::string classTypeName;

	v8::Local<v8::FunctionTemplate> objTempl;
	std::vector<std::unique_ptr<IObjectProp>> props;
	std::vector<std::unique_ptr<IObjectProp>> ind_props;
	std::vector<std::string> fields;
	std::vector<std::unique_ptr<IObjectMethod>> methods;
	std::vector<std::unique_ptr<IDelphiEnumValue>> enums;

	bool HasIndexedProps = false;
	int FieldCount = 0;
protected:
	std::vector<char> runStringResult;
private:
	v8::Isolate * iso = nullptr;
};

class IEngine : public IBazisIntf {
public:
	~IEngine();
	IEngine(void * DEngine);

	//std::stack<std::unique_ptr<v8::Isolate>> isolates;
	v8::Isolate * isolate = nullptr;

	std::vector<char *> MakeArgs(char * codeParam, bool isFileName, int& argc, char * exePath, char * additionalParams);

	v8::Local<v8::FunctionTemplate> AddV8ObjectTemplate(IObjectTemplate * obj);

	virtual IObjectTemplate * APIENTRY AddGlobal(void * dClass, void * object);
	virtual IObjectTemplate * APIENTRY AddObject(char * classtype, void * dClass);
	virtual IObjectTemplate * APIENTRY GetObjectByClass(void * dClass);
	virtual bool APIENTRY ClassIsRegistered(void * dClass);

	virtual IValue * APIENTRY RunString(char * code, char * scriptName, char * scriptPath, char * additionalParams);
	virtual char * APIENTRY RunFile(char * fName, char * exeName, char * additionalParams);
	virtual char * APIENTRY RunIncludeFile(char * fName);
	virtual char * APIENTRY RunIncludeCode(char * code);
	virtual void APIENTRY AddIncludeCode(char * code);
	virtual IValue * APIENTRY CallFunc(char * funcName, IValueArray * args);
    virtual void APIENTRY SetInactive();

	virtual void APIENTRY SetDebug(bool debug, char * arg);
	bool DebugMode();
	virtual int APIENTRY ErrorCode();
	void SetErrorCode(int code);
	void ExecIncludeCode(v8::Local<v8::Context> context);

	virtual void APIENTRY SetMethodCallBack(TMethodCallBack callBack);
	virtual void APIENTRY SetPropGetterCallBack(TGetterCallBack callBack);
	virtual void APIENTRY SetPropSetterCallBack(TSetterCallBack callBack);
	virtual void APIENTRY SetFieldGetterCallBack(TGetterCallBack callBack);
	virtual void APIENTRY SetFieldSetterCallBack(TSetterCallBack callBack);
	virtual void APIENTRY SetIndexedPropGetterObjCallBack(TGetterCallBack callBack);
	virtual void APIENTRY SetIndexedPropGetterNumberCallBack(TGetterCallBack callBack);
	virtual void APIENTRY SetIndexedPropSetterNumberCallBack(TSetterCallBack callBack);
    virtual void APIENTRY SetNamedPropGetterNumberCallBack(TGetterCallBack callBack);
    virtual void APIENTRY SetNamedPropSetterNumberCallBack(TSetterCallBack callBack);
	virtual void APIENTRY SetInterfaceGetterPropCallBack(TGetterCallBack callBack);
	virtual void APIENTRY SetInterfaceSetterPropCallBack(TIntfSetterCallBack callBack);
	virtual void APIENTRY SetInterfaceMethodCallBack(TMethodCallBack callBack);
	virtual void APIENTRY SetErrorMsgCallBack(TErrorMsgCallBack callback);

	virtual IValueArray * APIENTRY NewArray(int count);
	virtual IValue * APIENTRY NewInteger(int value);
	virtual IValue * APIENTRY NewNumber(double value);
	virtual IValue * APIENTRY NewString(char * value);
	virtual IValue * APIENTRY NewBool(bool value);
    virtual IRecord * APIENTRY NewRecord();
	virtual IObject * APIENTRY NewObject(void * value, void * classtype);
    virtual IValue * APIENTRY NewInterfaceObject(void * value);


	void * globObject = nullptr;
	IObjectTemplate * globalTemplate = nullptr;
	void * DEngine = nullptr;

	virtual void* GetDelphiObject(v8::Local<v8::Object> holder);
	virtual void* GetDelphiClasstype(v8::Local<v8::Object> obj);

	v8::Local<v8::Object> FindObject(void * dObj, void * classType, v8::Isolate * iso);
	void AddObject(void * dObj, void * classType, v8::Local<v8::Object> obj, v8::Isolate * iso);

	void LogErrorMessage(const char * msg);

	v8::Local<v8::ObjectTemplate> MakeGlobalTemplate(v8::Isolate * iso);
	//will be initialized at MakeGlobalTemplate method.
	v8::Local<v8::ObjectTemplate> ifaceTemplate;
	v8::Local<v8::ObjectTemplate> indexedObjTemplate;
	
	//callback for delphi's interface method (TODO:: It shouldn't be public)
	static void InterfaceFuncCallBack(const v8::FunctionCallbackInfo<v8::Value>& args);
	static IEngine * GetEngine(v8::Isolate * iso);

private:
	std::vector<char> run_string_result;
	std::string include_code;
	std::vector<std::unique_ptr<IBazisIntf>> IValues;
	node::NodeEngine * node_engine;

	std::unordered_map<int64_t, v8::Persistent<v8::Object, v8::CopyablePersistentTraits<v8::Object>> > JSObjects;

	std::unique_ptr<IValueArray> run_result_array;
	std::unique_ptr<IValue> run_result_value;
    std::unique_ptr<IObject> run_result_object;

	TMethodCallBack methodCall;
	TGetterCallBack getterCall;
	TSetterCallBack setterCall;
	TGetterCallBack fieldGetterCall;
	TSetterCallBack fieldSetterCall;
	TGetterCallBack IndPropGetterObjCall;
	TGetterCallBack IndPropGetterCall;
	TSetterCallBack IndPropSetterCall;
    TGetterCallBack NamedPropGetterCall;
    TSetterCallBack NamedPropSetterCall;
	TGetterCallBack IFaceGetterPropCall;
	TIntfSetterCallBack IFaceSetterPropCall;
	TMethodCallBack IFaceMethodCall;
	TErrorMsgCallBack ErrMsgCallBack;
	bool debugMode = false;
    char * debugArg = nullptr;
	int errCode = 0;
	IValue * func_result;

	std::vector<std::unique_ptr<IObjectTemplate>> objects;
	std::vector<std::string> methods;
	std::vector<std::string> fields;
	std::vector<v8::Local<v8::ObjectTemplate>> v8Templates;

	static void IndexedPropObjGetter(v8::Local<v8::String> property,
		const v8::PropertyCallbackInfo<v8::Value>& info);
	static void IndexedPropGetter(unsigned int index, const v8::PropertyCallbackInfo<v8::Value>& info);
    static void NamedPropGetter(v8::Local<v8::String> property, const v8::PropertyCallbackInfo<v8::Value>& info);
	static void IndexedPropSetter(unsigned int index, v8::Local<v8::Value> value, const v8::PropertyCallbackInfo<v8::Value>& info);
    static void NamedPropSetter(v8::Local<v8::String> property, v8::Local<v8::Value> value, const v8::PropertyCallbackInfo<v8::Value>& info);

	static void FieldGetter(v8::Local<v8::String> property,
		const v8::PropertyCallbackInfo<v8::Value>& info);
	static void FieldSetter(v8::Local<v8::String> property, v8::Local<v8::Value> value,
		const v8::PropertyCallbackInfo<void>& info);

	static void Getter(v8::Local<v8::String> property,
		const v8::PropertyCallbackInfo<v8::Value>& info);
	static void Setter(v8::Local<v8::String> property, v8::Local<v8::Value> value,
		const v8::PropertyCallbackInfo<void>& info);

	static void InterfaceGetter(v8::Local<v8::Name> property,
		const v8::PropertyCallbackInfo<v8::Value>& info);
	static void InterfaceSetter(v8::Local<v8::Name> property, v8::Local<v8::Value> value,
		const v8::PropertyCallbackInfo<v8::Value>& info);

	static void FuncCallBack(const v8::FunctionCallbackInfo<v8::Value>& args);
    //callBack for toString() js method;
    static void toStringCallBack(const v8::FunctionCallbackInfo<v8::Value>& args);

	static void Throw_Exception(const char * error_msg);
	static void MessageListener(v8::Local<v8::Message> message, v8::Local<v8::Value> error);
};

//number of slot in isolate for engine;
const uint32_t EngineSlot = 0;
// <<--Object internal fields' consts
const int DelphiObjectIndex = 0;
const int DelphiClassTypeIndex = 1;

const int ObjectInternalFieldCount = 2;
// Object internal fields' consts-->>

namespace Bazis {
extern "C" {
    BZINTF int BZDECL GetMajorVersion();
    BZINTF int BZDECL GetMinorVersion();

	BZINTF IEngine* BZDECL InitEngine(void * DEngine);

	BZINTF IEngine* BZDECL InitGlobalEngine(void * DEngine);

    BZINTF void BZDECL InitializeNode();

	BZINTF void BZDECL FinalizeNode();
}
}

}
