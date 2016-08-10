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

#define APIENTRY __stdcall
#define BZINTF _declspec(dllexport)
#define BZDECL __cdecl
#define BZDEPRECATED _declspec(deprecated)


namespace Bv8 {

class IValue;

class IBazisIntf {
public:
	virtual ~IBazisIntf() {};
	virtual void APIENTRY Delete() { delete this; };
	virtual int APIENTRY TestFun() { return 101; };
};

class IObject : public IBazisIntf {
public:
	IObject(v8::Isolate * isolate, v8::Local<v8::Object> object);
	virtual bool APIENTRY IsDelphiObject();
	virtual void* APIENTRY GetDelphiObject();
	virtual void* APIENTRY GetDelphiClasstype();
private:
	v8::Isolate * iso = nullptr;
	v8::Persistent<v8::Object> obj;
	bool isDObject = false;
};

class IFunction : public IBazisIntf {
public:
	IFunction(v8::Local<v8::Function> function, v8::Isolate * isolate);
	virtual void APIENTRY AddArgAsInt(int val);
	virtual void APIENTRY AddArgAsBool(bool val);
	virtual void APIENTRY AddArgAsString(char* val);
	virtual void APIENTRY AddArgAsNumber(double val);
	virtual void APIENTRY AddArgAsObject(void * obj);
	virtual IValue * APIENTRY CallFunction();
private:
	v8::Isolate * iso = nullptr;
	std::vector<v8::Local<v8::Value>> argv;
	v8::Persistent<v8::Function> func;
	IValue * returnVal = nullptr;
};

class IValueArray : public IBazisIntf {
public:
	IValueArray(v8::Isolate * isolate, v8::Local<v8::Array> values_arr);
	IValueArray(v8::Isolate * isolate, int count);
	virtual int APIENTRY GetCount();
	virtual IValue * APIENTRY GetValue(int index);
	virtual void APIENTRY SetValue(IValue * value, int index);

	std::vector<v8::Local<v8::Value>> GeV8ValueVector();
	v8::Local<v8::Array> GetV8Array();
private:
	std::vector<std::unique_ptr<IValue>> values;
	v8::Persistent<v8::Array> arr;
	int length = -1;
	v8::Isolate * iso = nullptr;
};

class IRecord : public IBazisIntf {
public:
	IRecord(v8::Isolate * isolate);
	IRecord(v8::Isolate * isolate, v8::Local<v8::Object> localObj);
	v8::Persistent<v8::Object> obj;

	virtual void APIENTRY SetIntField(char * name, int val);
	virtual void APIENTRY SetDoubleField(char * name, double val);
	virtual void APIENTRY SetBoolField(char * name, bool val);
	virtual void APIENTRY SetStringField(char * name, char * val);
	virtual void APIENTRY SetObjectField(char * name, void * val);

	virtual int APIENTRY GetIntField(char * name);
	virtual double APIENTRY GetDoubleField(char * name);
	virtual bool APIENTRY GetBoolField(char * name);
	virtual char * APIENTRY GetStringField(char * name);
	virtual void * APIENTRY GetObjectField(char * name);
private:
	v8::Isolate * iso = nullptr;
	std::vector<char> run_string_result;
};

class IValue : public IBazisIntf {
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
	v8::Local<v8::Value> GetV8Value();
private:
	v8::Persistent<v8::Value> v8Value;
	v8::Isolate * isolate = nullptr;
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
	virtual int APIENTRY GetArgsCount();;

	virtual char * APIENTRY GetMethodName();;

	virtual void APIENTRY SetReturnValueClass(void * value, void* dClasstype);
	virtual void APIENTRY SetReturnValueInt(int val);
	virtual void APIENTRY SetReturnValueBool(bool val);
	virtual void APIENTRY SetReturnValueString(char * val);
	virtual void APIENTRY SetReturnValueDouble(double val);
	virtual void APIENTRY SetReturnValueAsRecord();
	virtual IRecord * APIENTRY GetReturnValueAsRecord();

	virtual IValue * APIENTRY GetArg(int index);
	virtual void * APIENTRY GetDelphiMethod();
private:
	v8::Isolate * iso = nullptr;
	IRecord * recVal = nullptr;
	std::vector<std::unique_ptr<IValue>> values;
	const v8::FunctionCallbackInfo<v8::Value>* args = nullptr;
	std::vector<char> run_string_result;
};

class IGetterArgs : public IBazisIntf {
public:
	IGetterArgs(const v8::PropertyCallbackInfo<v8::Value>& info, char * prop);
	IGetterArgs(const v8::PropertyCallbackInfo<v8::Value>& info, int index);
	virtual void * APIENTRY GetEngine();
	virtual void * APIENTRY GetDelphiObject();
	virtual void * APIENTRY GetDelphiClasstype();
	virtual char * APIENTRY GetPropName();
	virtual int APIENTRY GetPropIndex();

	virtual void APIENTRY SetGetterResultDObject(void * value, void* dClasstype);
	virtual void APIENTRY SetGetterResultInt(int val);
	virtual void APIENTRY SetGetterResultBool(bool val);
	virtual void APIENTRY SetGetterResultString(char * val);
	virtual void APIENTRY SetGetterResultDouble(double val);
	virtual void APIENTRY SetGetterResultAsRecord();
	virtual IRecord * APIENTRY GetGetterResultAsRecord();

private:
	v8::Isolate * iso = nullptr;
	IRecord * recVal = nullptr;
	bool IsIndexedProp = false;
	std::string propName = "";
	int propInd = -1;
	const v8::PropertyCallbackInfo<v8::Value> * propinfo = nullptr;
	std::vector<char> run_string_result;
};

class ISetterArgs : public IBazisIntf {
public:
	ISetterArgs(const v8::PropertyCallbackInfo<void>& info, char * prop, v8::Local<v8::Value> newValue);
	ISetterArgs(const v8::PropertyCallbackInfo<v8::Value>& info, int index, v8::Local<v8::Value> newValue);
	virtual void * APIENTRY GetEngine();
	virtual void * APIENTRY GetDelphiObject();
	virtual void * APIENTRY GetDelphiClasstype();
	virtual char * APIENTRY GetPropName();
	virtual int APIENTRY GetPropIndex();
	virtual IValue * APIENTRY GetValue();

	virtual void * APIENTRY GetValueAsDObject();
	virtual int APIENTRY GetValueAsInt();
	virtual bool APIENTRY GetValueAsBool();
	virtual char * APIENTRY GetValueAsString();
	virtual double APIENTRY GetValueAsDouble();
private:
	v8::Isolate * iso = nullptr;
	bool IsIndexedProp = false;
	std::string propName = "";
	int propInd = -1;
	std::vector<char> run_string_result;
	const v8::PropertyCallbackInfo<void> * propinfo = nullptr;
	const v8::PropertyCallbackInfo<v8::Value> * indexedPropInfo = nullptr;
	v8::Persistent<v8::Value> newVal;
	IValue * setterVal = nullptr;
};

typedef void(APIENTRY *TMethodCallBack) (IMethodArgs * args);
typedef void(APIENTRY *TGetterCallBack) (IGetterArgs * args);
typedef void(APIENTRY *TSetterCallBack) (ISetterArgs * args);

class IObjectProp : public IBazisIntf {
public:
	virtual void APIENTRY SetRead(bool Aread);;
	virtual void APIENTRY SetWrite(bool Awrite);
	virtual void APIENTRY setName(char * Aname);
	IObjectProp(std::string pName, bool pRead = true, bool Pwrite = true);
	IObjectProp();
	std::string name = "";
	bool read = true;
	bool write = true;
};

class IObjectMethod : public IBazisIntf {
public:
	std::string name = "";
	void * call = nullptr;
};

class IObjectTemplate : public IBazisIntf {
public:
	virtual void APIENTRY SetMethod(char * methodName, void * methodCall);
	virtual void APIENTRY SetProp(char* propName, bool read, bool write);
	virtual void APIENTRY SetField(char* fieldName);
	virtual void APIENTRY SetHasIndexedProps(bool hasIndProps);
	virtual void APIENTRY SetClasstype(char* classtype);
	virtual char * APIENTRY GetClasstype();
	virtual void APIENTRY SetParent(IObjectTemplate * parent);

	std::string classtype;
	void * DClass = nullptr;
	v8::Persistent<v8::FunctionTemplate> objTempl;
	IObjectTemplate(std::string objclasstype, v8::Isolate * isolate);
	std::vector<std::unique_ptr<IObjectProp>> props;
	std::vector<std::string> fields;
	std::vector<std::unique_ptr<IObjectMethod>> methods;
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
	bool report_exceptions = true;
	bool print_result = true;
	bool node_initialized;
	node::Environment * cur_env;

	std::vector<char *> MakeArgs(char * codeParam, bool isFileName, int& argc);

	v8::Local<v8::FunctionTemplate> AddV8ObjectTemplate(IObjectTemplate * obj);

	virtual IObjectTemplate * APIENTRY AddGlobal(void * dClass, void * object);
	virtual IObjectTemplate * APIENTRY AddObject(char * classtype, void * dClass);
	virtual IObjectTemplate * APIENTRY GetObjectByClass(void * dClass);
	virtual char * APIENTRY RunString(char * code, char * exeName);
	virtual char * APIENTRY RunFileWithExePath(char * fName, char * exeName);
	virtual char * APIENTRY RunOneMoreFile(char * fName);
	virtual IValue * APIENTRY CallFunc(char * funcName, IValueArray * args);
	virtual void APIENTRY SetDebug(bool debug);
	bool DebugMode();
	virtual int APIENTRY ErrorCode();
	void SetErrorCode(int code);
	virtual void APIENTRY SetMethodCallBack(TMethodCallBack callBack);
	virtual void APIENTRY SetPropGetterCallBack(TGetterCallBack callBack);
	virtual void APIENTRY SetPropSetterCallBack(TSetterCallBack callBack);
	virtual void APIENTRY SetFieldGetterCallBack(TGetterCallBack callBack);
	virtual void APIENTRY SetFieldSetterCallBack(TSetterCallBack callBack);
	virtual void APIENTRY SetIndexedPropGetterCallBack(TGetterCallBack callBack);
	virtual void APIENTRY SetIndexedPropSetterCallBack(TSetterCallBack callBack);

	virtual IValueArray * APIENTRY NewArray(int count);
	virtual IValue * APIENTRY NewInteger(int value);
	virtual IValue * APIENTRY NewString(char * value);
	virtual IValue * APIENTRY NewBool(bool value);

	void * globObject = nullptr;
	IObjectTemplate * globalTemplate = nullptr;
	void * DEngine = nullptr;

	virtual void* GetDelphiObject(v8::Local<v8::Object> holder);
	virtual void* GetDelphiClasstype(v8::Local<v8::Object> obj);

	v8::Local<v8::ObjectTemplate> MakeGlobalTemplate(v8::Isolate * iso);
	v8::Persistent<v8::FunctionTemplate> glob;

private:
	std::vector<char> run_string_result;
	std::vector<std::unique_ptr<IBazisIntf>> IValues;


#ifdef DEBUG
	const char* blob_bin_dir = "D:\\Script Editor\\sources\\ScriptEngineLib\\Debug\\";
#else
	const char* blob_bin_dir = "D:\\Script Editor\\sources\\ScriptEngineLib\\Release\\";
#endif

	TMethodCallBack methodCall;
	TGetterCallBack getterCall;
	TSetterCallBack setterCall;
	TGetterCallBack fieldGetterCall;
	TSetterCallBack fieldSetterCall;
	TGetterCallBack IndPropGetterCall;
	TSetterCallBack IndPropSetterCall;
	char* name = "";
	bool debugMode = false;
	int errCode = 0;
	IValue * func_result;

	std::vector<std::unique_ptr<IObjectTemplate>> objects;
	std::vector<std::string> methods;
	std::vector<std::string> fields;
	std::vector<v8::Local<v8::ObjectTemplate>> v8Templates;

	static void IndexedPropGetter(unsigned int index, const v8::PropertyCallbackInfo<v8::Value>& info);
	static void IndexedPropSetter(unsigned int index, v8::Local<v8::Value> value, const v8::PropertyCallbackInfo<v8::Value>& info);

	static void FieldGetter(v8::Local<v8::String> property,
		const v8::PropertyCallbackInfo<v8::Value>& info);
	static void FieldSetter(v8::Local<v8::String> property, v8::Local<v8::Value> value,
		const v8::PropertyCallbackInfo<void>& info);

	static void Getter(v8::Local<v8::String> property,
		const v8::PropertyCallbackInfo<v8::Value>& info);
	static void Setter(v8::Local<v8::String> property, v8::Local<v8::Value> value,
		const v8::PropertyCallbackInfo<void>& info);
	static void FuncCallBack(const v8::FunctionCallbackInfo<v8::Value>& args);
};

namespace Bazis {
extern "C" {
	BZINTF IEngine* BZDECL InitEngine(void * DEngine);

	BZINTF void BZDECL FinalizeNode();

	BZINTF int BZDECL GetEngineVersion();

}
}
}
