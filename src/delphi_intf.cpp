#include "delphi_intf.h"

#include <iostream>
#include <sstream>
#include <fstream>
#include <streambuf>
#include <regex>
#include "uv.h"

namespace Bv8 {

const char * dObjectToStringDelimiter = " ";
const int dObjectToStringDelimiterLength = 1;


namespace Bazis {
	bool nodeInitialized = false;

    BZINTF int BZDECL GetMajorVersion()
    {
        return 1;
    }

    BZINTF int BZDECL GetMinorVersion()
    {
        return 0;
    }

	BZINTF IEngine *BZDECL InitEngine(void * DEngine)
	{
		try {
            InitializeNode();
			return new IEngine(DEngine);
		}
		catch(node::V8Exception &e){
			return nullptr;
		}
	}

	IEngine * global_engine = nullptr;

	BZINTF IEngine *BZDECL InitGlobalEngine(void * DEngine)
	{
		try {
            InitializeNode();
			global_engine = new IEngine(DEngine);
			return global_engine;
		}
		catch (node::V8Exception &e) {
			return nullptr;
		}
	}

    BZINTF void BZDECL InitializeNode()
    {
        if (!nodeInitialized) {
            std::vector<char *> args;
            args.push_back("");
            node::InitIalize(1, args.data());
            nodeInitialized = true;
        }
        return;
    }

	BZINTF void BZDECL FinalizeNode()
	{
		if (nodeInitialized) {
			node::Dispose();
			nodeInitialized = false;
		}
	}
    // this class makes node finalization (node initializes when first engine is created)
    class Finalizer {
    public:
        Finalizer() {};
        ~Finalizer() {
            FinalizeNode();
        };
    } finalizeer;
}

IObjectTemplate * IEngine::GetObjectByClass(void * dClass)
{
	// TODO: std::unordered_map
	for (auto &obj : objects) {
		if (obj->DClass == dClass)
			return obj.get();
	}
	return nullptr;
}

bool IEngine::ClassIsRegistered(void * dClass)
{
	return (GetObjectByClass(dClass) != nullptr);
}

std::vector<char *> IEngine::MakeArgs(char * codeParam, bool isFileName, int& argc, char * scriptName, char * additionalParams)
{
	std::vector<char *> args;
	args.push_back(scriptName);
	argc = 1;
	static char* arg0 = "";
	static char* arg1 = "";
	static char* arg2 = "";
	if (DebugMode()) {
		args.push_back(debugArg);
		arg2 = "--nolazy";
		args.push_back(arg2);
		argc += 2;
	}
	if (codeParam != "") {
		if (isFileName) {
			arg1 = codeParam;
			args.push_back(arg1);
			argc++;
		}
		else {
			args.push_back("-e");
			arg0 = codeParam;
			args.push_back(arg0);
            args.push_back("-f");
            arg1 = scriptName;
            args.push_back(arg1);
            argc += 4;
            //if it possible, find better way to synchronize default arguments & their count for 'eval' and 'debug' modes
            args.push_back(scriptName);
            argc++;
		}
	}
    if (additionalParams) {
        std::string params = additionalParams;        
        while (!params.empty()) {
            int strpos = params.find('\n\r');
            std::string subStr;
            if (strpos >= 0) {
                subStr = params.substr(0, strpos);
            }
            else {
                subStr = params;
            }                
            char * arg = new char[subStr.size() + 1];
            std::copy(subStr.begin(), subStr.end(), arg);
            arg[subStr.size()] = '\0';
            if (arg != "" && arg != "\r") {
                args.push_back(arg);
                argc++;
            }
            if (strpos < 0) {
                break;
            }

            params = params.substr(strpos + 2, params.length() - strpos - 2);
        }
    }
	return args;
}

v8::Local<v8::FunctionTemplate> IEngine::AddV8ObjectTemplate(IObjectTemplate * obj)
{
	obj->FieldCount = ObjectInternalFieldCount;
	auto V8Object = v8::FunctionTemplate::New(isolate);
    V8Object->SetClassName(v8::String::NewFromUtf8(isolate, obj->classTypeName.c_str(), v8::NewStringType::kNormal).ToLocalChecked());
	for (auto &field : obj->fields) {
		V8Object->InstanceTemplate()->SetAccessor(v8::String::NewFromUtf8(isolate, field.c_str(), v8::NewStringType::kNormal).ToLocalChecked(),
			FieldGetter, FieldSetter);
	}
	for (auto &prop : obj->props) {
		V8Object->InstanceTemplate()->SetAccessor(v8::String::NewFromUtf8(isolate, prop->name.c_str(), v8::NewStringType::kNormal).ToLocalChecked(),
			prop->read? Getter : (v8::AccessorGetterCallback)0,
			prop->write? Setter : (v8::AccessorSetterCallback)0, 
			v8::External::New(isolate, prop->obj));
	}

	auto inc = 0;
	for (auto &method : obj->methods) {
		v8::Local<v8::FunctionTemplate> methodCallBack = v8::FunctionTemplate::New(isolate, FuncCallBack, v8::External::New(isolate, method->call));
		V8Object->InstanceTemplate()->Set(v8::String::NewFromUtf8(isolate, method->name.c_str(), v8::NewStringType::kNormal).ToLocalChecked(), methodCallBack);
	}
    V8Object->InstanceTemplate()->Set(v8::String::NewFromUtf8(isolate, "toString", v8::NewStringType::kNormal).ToLocalChecked(), v8::FunctionTemplate::New(isolate, toStringCallBack));

	for (auto &prop : obj->ind_props) {
		V8Object->InstanceTemplate()->SetAccessor(v8::String::NewFromUtf8(isolate, prop->name.c_str(), v8::NewStringType::kNormal).ToLocalChecked(),
			prop->read ? IndexedPropObjGetter : (v8::AccessorGetterCallback)0, (v8::AccessorSetterCallback)0,
			v8::External::New(isolate, prop->obj));
	}

	if (obj->HasIndexedProps) {
		V8Object->InstanceTemplate()->SetIndexedPropertyHandler(IndexedPropGetter, IndexedPropSetter);
	}
	V8Object->InstanceTemplate()->SetInternalFieldCount(obj->FieldCount);
	obj->objTempl = V8Object;
	return V8Object;
}

IObjectTemplate * IEngine::AddGlobal(void * dClass, void * object)
{
	globalTemplate = new IObjectTemplate("global", isolate);
	globalTemplate->DClass = dClass;
	globObject = object;
	return globalTemplate;
}

inline IObjectTemplate * IEngine::AddObject(char * classtype, void * dClass) {
	auto object = std::make_unique<IObjectTemplate>(classtype, isolate);
	object->DClass = dClass;
	auto result = object.get();
	objects.push_back(std::move(object));
	return result;
}

static void log(const v8::FunctionCallbackInfo<v8::Value>& args) {
	if (args.Length() < 1) return;
	v8::HandleScope scope(args.GetIsolate());
	v8::Local<v8::Value> arg = args[0];
	v8::String::Utf8Value value(arg);
	std::string strval(*value);
	strval = "log: " + strval + "\n";
	printf(strval.c_str());
}

inline IValue * IEngine::RunString(char * code, char * scriptName, char * scriptPath, char * additionalParams) {
	try {
		errCode = -1;
		int argc = 0;
		auto argv = MakeArgs(code, false, argc, scriptName, additionalParams);
		uv_chdir(scriptPath);
		node_engine->RunScript(argc, argv.data(), [this](int code) {this->SetErrorCode(code); }, this);
	}
	catch (node::V8Exception &e) {
		errCode = 1000;
	}
	/*
	auto res = std::to_string(errCode);
	run_string_result = std::vector<char>(res.c_str(), res.c_str() + res.length());
	run_string_result.push_back(0);
	return run_string_result.data();*/
	return new IValue(isolate, v8::Integer::New(isolate, errCode), -1);
}

char * IEngine::RunFile(char * fName, char * exeName, char * additionalParams)
{
	try {
		int argc = 0;
		auto argv = MakeArgs(fName, true, argc, exeName, additionalParams);
        std::string filePath = fName;
        size_t pos = filePath.find_last_of("\\/");
        filePath = (std::string::npos == pos)? "" : filePath.substr(0, pos);
        uv_chdir(filePath.c_str());
		node_engine->RunScript(argc, argv.data(), [this](int code) {this->SetErrorCode(code); }, this);
	}
	catch (node::V8Exception &e) {
		errCode = 1000;
	}
	auto res = std::to_string(errCode);
	run_string_result = std::vector<char>(res.c_str(), res.c_str() + res.length());
	run_string_result.push_back(0);
	return run_string_result.data();
}

char * IEngine::RunIncludeFile(char * fName)
{
	v8::Local<v8::String> source;
	{
		std::ifstream t(fName);
		std::stringstream buffer;
		buffer << t.rdbuf();
		auto buf_str = buffer.str();
		auto source_str = buf_str.data();
		source = v8::String::NewFromUtf8(isolate, source_str, v8::NewStringType::kNormal).ToLocalChecked();
	}

	v8::ScriptOrigin origin(v8::String::NewFromUtf8(isolate, fName, v8::NewStringType::kNormal).ToLocalChecked());
	auto context = isolate->GetCurrentContext();
	//for debug>>>>>>>>>
	//<<<<<<<<<for debug
	v8::Local<v8::Script> script;
	if (v8::Script::Compile(context, source, &origin).ToLocal(&script)) {
		script->Run(context);
	}

	auto res = std::to_string(errCode);
	run_string_result = std::vector<char>(res.c_str(), res.c_str() + res.length());
	run_string_result.push_back(0);
	return run_string_result.data();
}

char * IEngine::RunIncludeCode(char * code)
{
	v8::Local<v8::String> source = v8::String::NewFromUtf8(isolate, code, v8::NewStringType::kNormal).ToLocalChecked();

	v8::ScriptOrigin origin(source);
	auto context = isolate->GetCurrentContext();
	//for debug>>>>>>>>>
	//<<<<<<<<<for debug
	v8::Local<v8::Script> script;
	if (v8::Script::Compile(context, source, &origin).ToLocal(&script)) {
		script->Run(context);
	}

	auto res = std::to_string(errCode);
	run_string_result = std::vector<char>(res.c_str(), res.c_str() + res.length());
	run_string_result.push_back(0);
	return run_string_result.data();
}

void IEngine::AddIncludeCode(char * code)
{
	include_code += code;
	include_code += "\n";
}

IValue * IEngine::CallFunc(char * funcName, IValueArray * args)
{
	v8::Isolate::Scope scope(isolate);
	auto context = isolate->GetCurrentContext();
	auto glo = context->Global();

	auto maybe_val = glo->Get(context, v8::String::NewFromUtf8(isolate, funcName, v8::NewStringType::kNormal).ToLocalChecked());
	if (!maybe_val.IsEmpty()) {
		auto val = maybe_val.ToLocalChecked();
		if (val->IsFunction()) {
			try {
				auto func = val.As<v8::Function>();
				std::vector<v8::Local<v8::Value>> argv = args->GeV8ValueVector();
				auto func_result = func->Call(context, glo, argv.size(), argv.data());
				if (!func_result.IsEmpty()) {
					auto result_value = std::make_unique<IValue>(isolate, func_result.ToLocalChecked(), -1);
					auto result = result_value.get();
					IValues.push_back(std::move(result_value));
					return result;
				}
			}
			catch (node::V8Exception &e) {
				return nullptr;
			}
				
		}
	}
	return nullptr;
}

void IEngine::SetInactive()
{
    isolate->SetData(EngineSlot, nullptr);
}

void IEngine::SetDebug(bool debug, char * arg)
{
	debugMode = debug;
    debugArg = arg;
}

bool IEngine::DebugMode()
{		
	return debugMode;
}

int IEngine::ErrorCode()
{
	return errCode;
}

void IEngine::SetErrorCode(int code)
{
	errCode = code;
}

void IEngine::ExecIncludeCode(v8::Local<v8::Context> context)
{
	v8::Local<v8::String> source = v8::String::NewFromUtf8(isolate, include_code.c_str(), v8::NewStringType::kNormal).ToLocalChecked();

	v8::ScriptOrigin origin(v8::String::NewFromUtf8(isolate, "", v8::NewStringType::kNormal).ToLocalChecked());
	//auto context = isolate->GetCurrentContext();
	v8::Local<v8::Script> script;
	if (v8::Script::Compile(context, source, &origin).ToLocal(&script)) {
		script->Run(context);
	}
}

inline void IEngine::SetMethodCallBack(TMethodCallBack callBack) {
	methodCall = callBack;
}

void IEngine::SetPropGetterCallBack(TGetterCallBack callBack)
{
	getterCall = callBack;
}



void IEngine::SetPropSetterCallBack(TSetterCallBack callBack)
{
	setterCall = callBack;
}

void IEngine::SetFieldGetterCallBack(TGetterCallBack callBack)
{
	fieldGetterCall = callBack;
}

void IEngine::SetFieldSetterCallBack(TSetterCallBack callBack)
{
	fieldSetterCall = callBack;
}

void IEngine::SetIndexedPropGetterObjCallBack(TGetterCallBack callBack)
{
	IndPropGetterObjCall = callBack;
}

void IEngine::SetIndexedPropGetterNumberCallBack(TGetterCallBack callBack)
{
	IndPropGetterCall = callBack;
}

void IEngine::SetIndexedPropSetterNumberCallBack(TSetterCallBack callBack)
{
	IndPropSetterCall = callBack;
}

void IEngine::SetNamedPropGetterNumberCallBack(TGetterCallBack callBack)
{
    NamedPropGetterCall = callBack;
}

void IEngine::SetNamedPropSetterNumberCallBack(TSetterCallBack callBack)
{
    NamedPropSetterCall = callBack;
}

void IEngine::SetInterfaceGetterPropCallBack(TGetterCallBack callBack)
{
	IFaceGetterPropCall = callBack;
}

void IEngine::SetInterfaceSetterPropCallBack(TIntfSetterCallBack callBack)
{
	IFaceSetterPropCall = callBack;
}

void IEngine::SetInterfaceMethodCallBack(TMethodCallBack callBack)
{
	IFaceMethodCall = callBack;
}

void IEngine::SetErrorMsgCallBack(TErrorMsgCallBack callback)
{
	ErrMsgCallBack = callback;
}

void IEngine::SetClassTypeChecker(TClassTypeChecker callBack)
{
	CheckClassType = callBack;
}

IValueArray * IEngine::NewArray(int count)
{
	if (isolate) {
		v8::Isolate::Scope scope(isolate);
		run_result_array = std::make_unique<IValueArray>(isolate, count);
		auto new_array = run_result_array.get();
		IValues.push_back(std::move(run_result_array));
		return new_array;
	}
	return nullptr;
}

IValue * IEngine::NewInteger(int value)
{
	if (isolate) {
		v8::Isolate::Scope scope(isolate);
		run_result_value = std::make_unique<IValue>(isolate, v8::Integer::New(isolate, value), -1);
		auto result = run_result_value.get();
		IValues.push_back(std::move(run_result_value));
		return result;
	}
	return nullptr;
}

IValue * IEngine::NewNumber(double value)
{
	if (isolate) {
		v8::Isolate::Scope scope(isolate);
		run_result_value = std::make_unique<IValue>(isolate, v8::Number::New(isolate, value), -1);
		auto result = run_result_value.get();
		IValues.push_back(std::move(run_result_value));
		return result;
	}
	return nullptr;
}

IValue * IEngine::NewString(char * value)
{
	if (isolate) {
		v8::Isolate::Scope scope(isolate);
		run_result_value = std::make_unique<IValue>(isolate, v8::String::NewFromUtf8(isolate, value, v8::NewStringType::kNormal).ToLocalChecked(), -1);
		auto result = run_result_value.get();
		IValues.push_back(std::move(run_result_value));
		return result;
	}
	return nullptr;
}

IValue * IEngine::NewBool(bool value)
{
	if (isolate) {
		v8::Isolate::Scope scope(isolate);
		run_result_value = std::make_unique<IValue>(isolate, v8::Boolean::New(isolate, value), -1);
		auto result = run_result_value.get();
		IValues.push_back(std::move(run_result_value));
		return result;
	}
	return nullptr;
}

IRecord * IEngine::NewRecord()
{
    std::unique_ptr<IRecord> res_value = std::make_unique<IRecord>(isolate);
    auto result = res_value.get();
    IValues.push_back(std::move(res_value));
    return result;
}

IObject * IEngine::NewObject(void * value, void * classtype)
{
    if (isolate) {
        v8::Isolate::Scope scope(isolate);
        IEngine * eng = IEngine::GetEngine(isolate);
        IObject * result = nullptr;
		if (!eng->ClassIsRegistered(classtype)) {
			classtype = eng->GetRegisteredParentClasstype(classtype);
		}
        auto obj = FindObject(value, classtype, isolate);
        if (obj.IsEmpty()) {
            auto dTempl = eng->GetObjectByClass(classtype);
            if (dTempl) {
                auto ctx = isolate->GetCurrentContext();
                auto maybeObj = dTempl->objTempl->InstanceTemplate()->NewInstance(ctx);
                obj = maybeObj.ToLocalChecked();
                obj->SetInternalField(DelphiObjectIndex, v8::External::New(isolate, value));
                obj->SetInternalField(DelphiClassTypeIndex, v8::External::New(isolate, classtype));
                AddObject(value, classtype, obj, isolate);
            }
        }
        if (!obj.IsEmpty()) {
            run_result_object = std::make_unique<IObject>(isolate, obj);
            result = run_result_object.get();
            IValues.push_back(std::move(run_result_value));
        }
        return result;
    }
	return nullptr;
}

IValue * IEngine::NewInterfaceObject(void * value)
{
    if (isolate) {
        auto ctx = isolate->GetCurrentContext();
        v8::Local<v8::Object> obj = ifaceTemplate->NewInstance(ctx).ToLocalChecked();
        obj->SetInternalField(DelphiObjectIndex, v8::External::New(isolate, value));
        run_result_value = std::make_unique<IValue>(isolate, obj, -1);
        auto result = run_result_value.get();
        IValues.push_back(std::move(run_result_value));
        return result;
    }
    return nullptr;
}


void * IEngine::GetDelphiObject(v8::Local<v8::Object> holder)
{
	int count = holder->InternalFieldCount();
	if ((count > 0)) {
		auto internalfield = holder->GetInternalField(DelphiObjectIndex);
		if (internalfield->IsExternal()) {
			auto classtype = internalfield.As<v8::External>();
			auto result = classtype->Value();
			return result;
		}
	}
	return nullptr;
}

void * IEngine::GetDelphiClasstype(v8::Local<v8::Object> obj)
{
	v8::Isolate::Scope scope(isolate);
	int count = obj->InternalFieldCount();
	// remove it if will be better way (needs only for "different global objects") ----
	if (count < 1) {
		obj = obj->GetPrototype()->ToObject(isolate->GetCurrentContext()).ToLocalChecked();
		count = obj->InternalFieldCount();
	}
	// ---- remove it if will be better way (needs only for "different global objects")
	if ((count > 0)) {
		auto internalfield = obj->GetInternalField(DelphiClassTypeIndex);
		if (internalfield->IsExternal()) {
			auto classtype = internalfield.As<v8::External>();
			auto result = classtype->Value();
			return result;
		}
		else
			return nullptr;
	}
	else
		return nullptr;
}

void * IEngine::GetRegisteredParentClasstype(void * classtype)
{
	return CheckClassType(classtype, this->DEngine);
}

v8::Local<v8::Object> IEngine::FindObject(void * dObj, void * classType, v8::Isolate * iso)
{
	uint64_t hash = (uint64_t(dObj) << 32) + uint32_t(classType);
	auto result = JSObjects.find(hash);
	if (result != JSObjects.end())
	{
		return result->second.Get(iso);
	}
	else
		return v8::Local<v8::Object>();
}

void IEngine::AddObject(void * dObj, void * classType, v8::Local<v8::Object> obj, v8::Isolate * iso)
{
	uint64_t hash = (uint64_t(dObj) << 32) + uint32_t(classType);
	v8::Persistent<v8::Object, v8::CopyablePersistentTraits<v8::Object>> persistent_obj(iso, obj);
	JSObjects.emplace(std::make_pair(hash, persistent_obj));
}

void IEngine::LogErrorMessage(const char * msg)
{
	if (ErrMsgCallBack) {
		ErrMsgCallBack(msg, DEngine);
	}
}

v8::Local<v8::ObjectTemplate> IEngine::MakeGlobalTemplate(v8::Isolate * iso)
{
	//isolate should be already entered;
	isolate = iso;
	////making iface template
	ifaceTemplate = v8::ObjectTemplate::New(iso);
	ifaceTemplate->SetInternalFieldCount(ObjectInternalFieldCount);
	v8::NamedPropertyHandlerConfiguration conf;
	conf.getter = InterfaceGetter;
	conf.setter = InterfaceSetter;
	ifaceTemplate->SetHandler(conf);
	////making indexed object template
	indexedObjTemplate = v8::ObjectTemplate::New(iso);
	indexedObjTemplate->SetInternalFieldCount(ObjectInternalFieldCount);
	indexedObjTemplate->SetIndexedPropertyHandler(IndexedPropGetter, IndexedPropSetter);
    indexedObjTemplate->SetNamedPropertyHandler(NamedPropGetter, NamedPropSetter);

	v8::Local<v8::FunctionTemplate> global = v8::FunctionTemplate::New(isolate);
	if (globalTemplate) {
		for (auto &method : globalTemplate->methods) {
			v8::Local<v8::FunctionTemplate> methodCallBack = v8::FunctionTemplate::New(isolate, FuncCallBack, v8::External::New(isolate, method->call));
			global->PrototypeTemplate()->Set(
				v8::String::NewFromUtf8(isolate, method->name.c_str(), v8::NewStringType::kNormal).ToLocalChecked(),
				methodCallBack);
		}

		for (auto &prop : globalTemplate->props) {
			auto prop_name = prop->name.c_str();
			global->PrototypeTemplate()->SetAccessor(v8::String::NewFromUtf8(isolate, prop_name, v8::NewStringType::kNormal).ToLocalChecked(), 
				Getter, 
				prop->write ? Setter : (v8::AccessorSetterCallback)0);
		}
		for (auto &enumField : globalTemplate->enums) {
			global->PrototypeTemplate()->Set(isolate, enumField->name.c_str(), v8::Integer::New(isolate, enumField->value));
		}
		global->PrototypeTemplate()->SetInternalFieldCount(ObjectInternalFieldCount);
	};
	for (auto &obj : objects) {
        auto classInfo = obj.get();
		auto V8ObjectTemplate = AddV8ObjectTemplate(classInfo);
        global->PrototypeTemplate()->Set(isolate, classInfo->classTypeName.c_str(), V8ObjectTemplate);
	}
	return global->PrototypeTemplate();
}

IEngine::IEngine(void * DEngine)
{
	this->DEngine = DEngine;
	ErrMsgCallBack = nullptr;
	include_code = "";
	node_engine = new node::NodeEngine();
}

IEngine::~IEngine()
{
	if (isolate)
		isolate->SetData(EngineSlot, nullptr);
	node_engine->StopScript();
	JSObjects.clear();
	delete node_engine;
}

void IEngine::IndexedPropObjGetter(v8::Local<v8::String> property,
	const v8::PropertyCallbackInfo<v8::Value>& info)
{
	IEngine * engine = IEngine::GetEngine(info.GetIsolate());
	if (!engine)
		return;
	v8::Isolate::Scope iso_scope(engine->isolate);
	if (engine->IndPropGetterObjCall) {
		v8::String::Utf8Value str(property);
		auto getterArgs = new IGetterArgs(info, *str);
		engine->IndPropGetterObjCall(getterArgs);
		if (getterArgs->error != "")
			engine->Throw_Exception(getterArgs->error.c_str());
	}
}

void IEngine::IndexedPropGetter(unsigned int index, const v8::PropertyCallbackInfo<v8::Value>& info)
{
	IEngine * engine = IEngine::GetEngine(info.GetIsolate());
	if (!engine)
		return;
	v8::Isolate::Scope iso_scope(engine->isolate);
	if (engine->IndPropGetterCall) {
		auto getterArgs = new IGetterArgs(info, index);
		engine->IndPropGetterCall(getterArgs);
		if (getterArgs->error != "")
			engine->Throw_Exception(getterArgs->error.c_str());
	}
}

void IEngine::NamedPropGetter(v8::Local<v8::String> property, const v8::PropertyCallbackInfo<v8::Value>& info)
{
    IEngine * engine = IEngine::GetEngine(info.GetIsolate());
    if (!engine)
        return;
    v8::Isolate::Scope iso_scope(engine->isolate);
    if (engine->NamedPropGetterCall) {
        auto getterArgs = new IGetterArgs(info, property);
        engine->NamedPropGetterCall(getterArgs);
        if (getterArgs->error != "")
            engine->Throw_Exception(getterArgs->error.c_str());
    }
}

void IEngine::IndexedPropSetter(unsigned int index, v8::Local<v8::Value> value, const v8::PropertyCallbackInfo<v8::Value>& info)
{
	info.GetReturnValue().SetNull();
	IEngine * engine = IEngine::GetEngine(info.GetIsolate());
	if (!engine)
		return;
	v8::Isolate::Scope iso_scope(engine->isolate);
	if (engine->IndPropSetterCall) {
		auto setterArgs = new ISetterArgs(info, index, value);
		engine->IndPropSetterCall(setterArgs);
		if (setterArgs->error != "")
			engine->Throw_Exception(setterArgs->error.c_str());
	}
}

void IEngine::NamedPropSetter(v8::Local<v8::String> property, v8::Local<v8::Value> value, const v8::PropertyCallbackInfo<v8::Value>& info)
{
    info.GetReturnValue().SetNull();
    IEngine * engine = IEngine::GetEngine(info.GetIsolate());
    if (!engine)
        return;
    v8::Isolate::Scope iso_scope(engine->isolate);
    if (engine->NamedPropSetterCall) {
        auto setterArgs = new ISetterArgs(info, property, value);
        engine->NamedPropSetterCall(setterArgs);
        if (setterArgs->error != "")
            engine->Throw_Exception(setterArgs->error.c_str());
    }
}

void IEngine::FieldGetter(v8::Local<v8::String> property, const v8::PropertyCallbackInfo<v8::Value>& info)
{
	IEngine * engine = IEngine::GetEngine(info.GetIsolate());
	if (!engine)
		return;
	v8::Isolate::Scope iso_scope(engine->isolate);
	if (engine->fieldGetterCall) {
		v8::String::Utf8Value str(property);
		auto getterArgs = new IGetterArgs(info, *str);
		engine->fieldGetterCall(getterArgs);
		if (getterArgs->error != "")
			engine->Throw_Exception(getterArgs->error.c_str());
	}
}

void IEngine::FieldSetter(v8::Local<v8::String> property, v8::Local<v8::Value> value, const v8::PropertyCallbackInfo<void>& info)
{
	info.GetReturnValue().SetNull();
	IEngine * engine = IEngine::GetEngine(info.GetIsolate());
	if (!engine)
		return;
	v8::Isolate::Scope iso_scope(engine->isolate);
	if (engine->fieldSetterCall) {
		v8::String::Utf8Value str(property);
		auto setterArgs = new ISetterArgs(info, *str, value);
		engine->fieldSetterCall(setterArgs);
		if (setterArgs->error != "")
			engine->Throw_Exception(setterArgs->error.c_str());
	}
}

void IEngine::Getter(v8::Local<v8::String> property, const v8::PropertyCallbackInfo<v8::Value>& info)
{
	IEngine * engine = IEngine::GetEngine(info.GetIsolate());
	if (!engine)
		return;
	v8::Isolate::Scope iso_scope(engine->isolate);
	if (engine->getterCall) {
		v8::String::Utf8Value str(property);
		auto getterArgs = new IGetterArgs(info, *str);
		engine->getterCall(getterArgs);
		if (getterArgs->error != "")
			engine->Throw_Exception(getterArgs->error.c_str());
	}
}

void IEngine::Setter(v8::Local<v8::String> property, v8::Local<v8::Value> value, const v8::PropertyCallbackInfo<void>& info)
{
	IEngine * engine = IEngine::GetEngine(info.GetIsolate());
	if (!engine)
		return;
	v8::Isolate::Scope iso_scope(engine->isolate);
	if (engine->setterCall) {
		v8::String::Utf8Value str(property);
		auto setterArgs = new ISetterArgs(info, *str, value);
		engine->setterCall(setterArgs);
		if (setterArgs->error != "")
			engine->Throw_Exception(setterArgs->error.c_str());
	}
}

void IEngine::InterfaceGetter(v8::Local<v8::Name> property, const v8::PropertyCallbackInfo<v8::Value>& info)
{
	IEngine * engine = IEngine::GetEngine(info.GetIsolate());
	if (!engine)
		return;
	v8::Isolate::Scope iso_scope(engine->isolate);
	if (engine->IFaceGetterPropCall) {
		v8::String::Utf8Value str(property);
		auto getterArgs = new IGetterArgs(info, *str);
		engine->IFaceGetterPropCall(getterArgs);
		if (getterArgs->error != "")
			engine->Throw_Exception(getterArgs->error.c_str());
	}
}

void IEngine::InterfaceSetter(v8::Local<v8::Name> property, v8::Local<v8::Value> value, const v8::PropertyCallbackInfo<v8::Value>& info)
{
	IEngine * engine = IEngine::GetEngine(info.GetIsolate());
	if (!engine)
		return;
	v8::Isolate::Scope iso_scope(engine->isolate);
	if (engine->IFaceSetterPropCall) {
		v8::String::Utf8Value str(property);
		auto setterArgs = new IIntfSetterArgs(info, *str, value);
		engine->IFaceSetterPropCall(setterArgs);
		if (setterArgs->error != "")
			engine->Throw_Exception(setterArgs->error.c_str());
	}
}

void IEngine::InterfaceFuncCallBack(const v8::FunctionCallbackInfo<v8::Value>& args)
{
	IEngine * engine = IEngine::GetEngine(args.GetIsolate());
	if (!engine)
		return;
	v8::Isolate::Scope iso_scope(engine->isolate);
	if (engine->IFaceMethodCall) {
		auto methodArgs = new IMethodArgs(args);
		engine->IFaceMethodCall(methodArgs);
		if (methodArgs->error != "")
			engine->Throw_Exception(methodArgs->error.c_str());
	}
}

void IEngine::FuncCallBack(const v8::FunctionCallbackInfo<v8::Value>& args)
{
	IEngine * engine = IEngine::GetEngine(args.GetIsolate());
	if (!engine)
		return;
	v8::Isolate::Scope iso_scope(engine->isolate);
	if (engine->methodCall) {
		auto methodArgs = new IMethodArgs(args);
		engine->methodCall(methodArgs);
		if (methodArgs->error != "")
			engine->Throw_Exception(methodArgs->error.c_str());
	}
}

void IEngine::toStringCallBack(const v8::FunctionCallbackInfo<v8::Value>& args)
{
    auto iso = args.GetIsolate();
    IEngine * engine = IEngine::GetEngine(iso);
    if (engine) {
        v8::Isolate::Scope iso_scope(engine->isolate);

        auto js_object = args.Holder();

        auto dObject = reinterpret_cast<uintptr_t>(engine->GetDelphiObject(js_object));
        auto dClasstype = reinterpret_cast<uintptr_t>(engine->GetDelphiClasstype(js_object));

        v8::String::Utf8Value cTypeName(js_object->GetConstructorName());
        std::string str = "[object " + std::string(*cTypeName) + "] " + std::to_string(dObject) + dObjectToStringDelimiter + std::to_string(dClasstype);
        args.GetReturnValue().Set(v8::String::NewFromUtf8(iso, str.c_str(), v8::NewStringType::kNormal).ToLocalChecked());
        
    }
}



void IEngine::Throw_Exception(const char * error_msg)
{
	auto iso = v8::Isolate::GetCurrent();
	iso->ThrowException(v8::String::NewFromUtf8(iso, error_msg));
}

void IEngine::MessageListener(v8::Local<v8::Message> message, v8::Local<v8::Value> error)
{
	IEngine * engine = IEngine::GetEngine(v8::Isolate::GetCurrent());
	if (!engine)
		return;
	v8::Isolate::Scope scope(engine->isolate);
	v8::String::Utf8Value str(message->Get());
	engine->LogErrorMessage(*str);
}

IEngine * IEngine::GetEngine(v8::Isolate * iso)
{
	if (iso)
		return static_cast<IEngine *>(iso->GetData(EngineSlot));
	/*auto ctx = iso->GetCurrentContext();
	if (*ctx)
		return static_cast<IEngine *>(ctx->GetAlignedPointerFromEmbedderData(EngineSlot));*/
	return nullptr;
}

inline void IObjectTemplate::SetMethod(char * methodName, void * methodCall) {
	auto method = std::make_unique<IObjectMethod>();
	method->name = methodName;
	method->call = methodCall;
	methods.push_back(std::move(method));
}

inline void IObjectTemplate::SetProp(char * propName, void * propObj, bool read, bool write) {
	auto newProp = std::make_unique<IObjectProp>(propName, propObj, read, write);
	props.push_back(std::move(newProp));
}

void IObjectTemplate::SetIndexedProp(char * propName, void * propObj, bool read, bool write)
{
	auto newProp = std::make_unique<IObjectProp>(propName, propObj, read, write);
	ind_props.push_back(std::move(newProp));
}

void IObjectTemplate::SetField(char * fieldName)
{
	fields.push_back(fieldName);
}

void IObjectTemplate::SetEnumField(char * valuename, int value)
{
	auto newField = std::make_unique<IDelphiEnumValue>(valuename, value);
	enums.push_back(std::move(newField));
}

void IObjectTemplate::SetHasIndexedProps(bool hasIndProps)
{
	HasIndexedProps = hasIndProps;
}

void IObjectTemplate::SetParent(IObjectTemplate * parent)
{
}

IObjectTemplate::IObjectTemplate(std::string objclasstype, v8::Isolate * isolate)
{
    classTypeName = objclasstype;
	iso = isolate;
}

inline void IObjectProp::SetRead(bool Aread) { read = Aread; }

void IObjectProp::SetWrite(bool Awrite)
{
	write = Awrite;
}

void IObjectProp::setName(char * Aname)
{
	name = Aname;
}

inline IObjectProp::IObjectProp(std::string pName, void * pObj, bool pRead, bool Pwrite) { name = pName; read = pRead; write = Pwrite; obj = pObj; }

inline IObjectProp::IObjectProp() {}

//check arg's classtype

inline bool IValue::ArgIsNumber() {
	return GetV8Value()->IsNumber() || GetV8Value()->IsUndefined();
}

bool IValue::ArgIsInt()
{
	return GetV8Value()->IsInt32() || GetV8Value()->IsUndefined();
}

inline bool IValue::ArgIsBool() {
	return GetV8Value()->IsBoolean() || GetV8Value()->IsUndefined();
}

inline bool IValue::ArgIsString() {
	return GetV8Value()->IsString() || GetV8Value()->IsUndefined();
}

bool IValue::ArgIsObject()
{
    auto result = GetV8Value()->IsObject();
    if (!result)
        if (GetObjectFromString())
            result = true;
    return result;
}
bool IValue::ArgIsArray()
{
	return GetV8Value()->IsArray() || GetV8Value()->IsUndefined();
}
bool IValue::ArgIsV8Function()
{
	return GetV8Value()->IsFunction() || GetV8Value()->IsUndefined();
}
bool IValue::ArgIsUndefined()
{
	return GetV8Value()->IsUndefined();
}
//get arg 

inline double IValue::GetArgAsNumber() {
	v8::Isolate::Scope scope(Isolate());
	return GetV8Value()->NumberValue(GetCurrentContext()).FromMaybe(0);
}

int IValue::GetArgAsInt()
{
	v8::Isolate::Scope scope(Isolate());
	return GetV8Value()->Int32Value(GetCurrentContext()).FromMaybe(0);
}

inline bool IValue::GetArgAsBool() {
	v8::Isolate::Scope scope(Isolate());
	return GetV8Value()->BooleanValue(GetCurrentContext()).FromMaybe(false);
}

inline char * IValue::GetArgAsString() {
	v8::Isolate::Scope scope(Isolate());
	v8::String::Utf8Value str(GetV8Value()->ToString());
	char *it1 = *str;
	char *it2 = *str + str.length();
	auto vec = std::vector<char>(it1, it2);
	run_string_result = vec;
	run_string_result.push_back(0);
	return run_string_result.data();
}

IObject * IValue::GetArgAsObject()
{
	v8::Isolate::Scope scope(Isolate());
	if (!obj) {
		auto arg = GetV8Value();
		if (arg->IsObject()) {
			auto maybeobj = arg->ToObject(GetCurrentContext());
			if (maybeobj.IsEmpty())
				return nullptr;
			obj = new IObject(Isolate(), maybeobj.ToLocalChecked());
		}
		else
			obj = GetObjectFromString();
	}
	return obj;
}

IValueArray * IValue::GetArgAsArray()
{
	v8::Isolate::Scope scope(Isolate());
	if (!arr)
		arr = new IValueArray(Isolate(), v8::Local<v8::Array>::Cast(GetV8Value()));
	return arr;
}

IRecord * IValue::GetArgAsRecord()
{
	if (!rec) {
		if (GetV8Value()->IsExternal())
			rec = static_cast<IRecord *>(GetV8Value().As<v8::External>()->Value());
		else
			rec = new IRecord(Isolate(), GetV8Value()->ToObject(GetCurrentContext()).ToLocalChecked());
	};
	return rec;
}

IFunction * IValue::GetArgAsFunction()
{
	if (!func) {
		func = new IFunction(GetV8Value().As<v8::Function>(), Isolate());
	}
	return func;
}

int IValue::GetIndex()
{
	return ind;
}

IObject * IValue::GetObjectFromString()
{
    std::regex objectString("\\[object *(\\w+)\\] *(\\d+) *(\\d+)");
    if (!obj) {
        if (GetV8Value()->IsString()) {
            v8::Isolate::Scope iso_scope(Isolate());
            v8::String::Utf8Value strUTF8(GetV8Value()->ToString());
            std::string str = *strUTF8;
            std::smatch match;
            if (std::regex_search(str, match, objectString)) {
                std::string match1 = match[2];
                std::string match2 = match[3];
                int dObjectPointer = std::atoi(match1.c_str());
                int dClasstype = std::atoi(match2.c_str());
                obj = IEngine::GetEngine(Isolate())->NewObject((void *)(dObjectPointer), (void *)dClasstype);
            }
        }
    }
    return obj;
}

IValue::IValue(v8::Isolate * iso, v8::Local<v8::Value> val, int index): IBaseValue(iso, val)
{
	ind = index;
}

void * IMethodArgs::GetDelphiObject()
{
	IEngine * eng = IEngine::GetEngine(iso);
	if (!eng)
		return nullptr;
	auto data = args->Data();
	if (data->IsArray()) {
		auto val = data.As<v8::Array>()->Get(iso->GetCurrentContext(), 0).ToLocalChecked();
		return val.As<v8::External>()->Value();
	}
	else {
		auto holder = args->Holder();
		return eng->GetDelphiObject(holder);
	}
}

void * IMethodArgs::GetDelphiClasstype()
{
	IEngine * eng = IEngine::GetEngine(iso);
	if (!eng)
		return nullptr;
	auto holder = args->Holder();
	return eng->GetDelphiClasstype(holder);
}

inline int IMethodArgs::GetArgsCount() {
	return args->Length();
}

inline char * IMethodArgs::GetMethodName() {
	v8::Isolate * iso = args->GetIsolate();
	auto data = args->Data();
	//it means, that data was written for delphi interface and contains info about delphi method
	if (data->IsArray()) {
		auto val = data.As<v8::Array>()->Get(iso->GetCurrentContext(), 1).ToLocalChecked();
		v8::String::Utf8Value str(val);
		char *it1 = *str;
		char *it2 = *str + str.length();
		auto vec = std::vector<char>(it1, it2);
		run_string_result = vec;
		run_string_result.push_back(0);
		return run_string_result.data();
	}
	else {
		v8::String::Utf8Value str(args->Callee()->GetName());
		char *it1 = *str;
		char *it2 = *str + str.length();
		auto vec = std::vector<char>(it1, it2);
		run_string_result = vec;
		run_string_result.push_back(0);
		return run_string_result.data();
	}
}

void IMethodArgs::SetReturnValueUndefined()
{
	args->GetReturnValue().SetUndefined();
}

void IMethodArgs::SetReturnValueIFace(void * value)
{
	v8::Isolate * iso = args->GetIsolate();
	IEngine * eng = IEngine::GetEngine(iso);
	auto ctx = iso->GetCurrentContext();
	v8::Local<v8::Object> obj = eng->ifaceTemplate->NewInstance(ctx).ToLocalChecked();
	obj->SetInternalField(DelphiObjectIndex, v8::External::New(iso, value));
	args->GetReturnValue().Set(obj);
}

void IMethodArgs::SetReturnValueClass(void * value, void* dClasstype)
{
	v8::Isolate * iso = args->GetIsolate();
	IEngine * eng = IEngine::GetEngine(iso);
	if (!eng->ClassIsRegistered(dClasstype)) {
		dClasstype = eng->GetRegisteredParentClasstype(dClasstype);
	}

	auto result = eng->FindObject(value, dClasstype, iso);
	if (!result.IsEmpty())
	{
		args->GetReturnValue().Set(result);
	}
	else {
		auto dTempl = eng->GetObjectByClass(dClasstype);
		if (dTempl) {
			auto ctx = iso->GetCurrentContext();
			auto maybeObj = dTempl->objTempl->InstanceTemplate()->NewInstance(ctx);
			if (!maybeObj.IsEmpty()) {
				auto obj = maybeObj.ToLocalChecked();
				obj->SetIntegrityLevel(ctx, v8::IntegrityLevel::kSealed);
				obj->SetInternalField(DelphiObjectIndex, v8::External::New(iso, value));
				obj->SetInternalField(DelphiClassTypeIndex, v8::External::New(iso, dClasstype));
				eng->AddObject(value, dClasstype, obj, iso);
				args->GetReturnValue().Set(obj);
			}
		}
	}
}

void IMethodArgs::SetReturnValueInt(int val)
{
	args->GetReturnValue().Set(val);
}

void IMethodArgs::SetReturnValueBool(bool val)
{
	args->GetReturnValue().Set(val);
}

void IMethodArgs::SetReturnValueString(char * val)
{
	auto str = v8::String::NewFromUtf8(args->GetIsolate(), val, v8::NewStringType::kNormal).ToLocalChecked();
	args->GetReturnValue().Set<v8::String>(str);
}

void IMethodArgs::SetReturnValueDouble(double val)
{
	args->GetReturnValue().Set(val);
}

void IMethodArgs::SetReturnValue(IBaseValue * val)
{
    if (val)
        args->GetReturnValue().Set<v8::Value>(val->GetV8Value());
}

IValue * IMethodArgs::GetArg(int index)
{
	for (auto &val : values) {
		if (val->GetIndex() == index)
			return val.get();
	}
	return nullptr;
}

void * IMethodArgs::GetDelphiMethod()
{
	if (args->Data()->IsExternal()) {
		return args->Data().As<v8::External>()->Value();
	}
	if (args->Data()->IsUndefined()) {
		std::cout << "FuncData is undefined, WTF??";
	}
	return nullptr;
}

void IMethodArgs::SetError(char * errorMsg)
{
	error = errorMsg;
}

void * IMethodArgs::GetEngine()
{
	IEngine * engine = IEngine::GetEngine(iso);
	if (!engine)
		return nullptr;
	return engine->DEngine;
}

inline IMethodArgs::IMethodArgs(const v8::FunctionCallbackInfo<v8::Value>& newArgs) {
	args = &newArgs;
	iso = args->GetIsolate();
	for (int i = 0; i < args->Length(); i++) {
		auto val = std::make_unique<IValue>(args->GetIsolate(), (*args)[i], i);
		values.push_back(std::move(val));
	}
}

IObject::IObject(v8::Isolate * isolate, v8::Local<v8::Object> object): IBaseValue(isolate, object)
{
	isDObject = (object->InternalFieldCount() > 0 ? object->GetInternalField(DelphiObjectIndex)->IsExternal() : false);
}

bool IObject::IsDelphiObject()
{
	return isDObject;
}

void * IObject::GetDelphiObject()
{
	if (isDObject) {
         auto maybeObj = GetV8Value()->ToObject(GetCurrentContext());
         if (!maybeObj.IsEmpty()) {
             auto objField = maybeObj.ToLocalChecked()->GetInternalField(DelphiObjectIndex);
             if (objField->IsExternal())
                 return objField.As<v8::External>()->Value();
         }
	}
	return nullptr;
}

void * IObject::GetDelphiClasstype()
{
	if (isDObject) {
        auto maybeObj = GetV8Value()->ToObject(GetCurrentContext());
        if (!maybeObj.IsEmpty()) {
            auto objField = maybeObj.ToLocalChecked()->GetInternalField(DelphiClassTypeIndex);
            if (objField->IsExternal())
                return objField.As<v8::External>()->Value();
        }
	}
	return nullptr;
}

IValueArray::IValueArray(v8::Isolate * isolate , v8::Local<v8::Array> values_arr): IBaseValue(isolate, values_arr)
{
	length = values_arr->Length();
	values.resize(length);
	/*for (uint32_t i = 0; i < values_arr->Length(); i++) {
		auto val = std::make_unique<IValue>(iso, values_arr->Get(iso->GetCurrentContext(), i).ToLocalChecked(), i);
		values.push_back(std::move(val));
	}*/
}

IValueArray::IValueArray(v8::Isolate * isolate, int count) : IBaseValue(isolate)
{
	length = count;
    v8::Local<v8::Array> local_arr = v8::Array::New(isolate, count);
    SetV8Value(local_arr);
}

int IValueArray::GetCount()
{
	return length;
}

IBaseValue * IValueArray::GetValue(int index)
{
	auto result = values[index].get();
	if (result)
		return result;
	else {
		values[index] = std::make_unique<IValue>(Isolate(), GetV8Array()->Get(GetCurrentContext(), index).ToLocalChecked(), index);
		return values[index].get();
	}
	return nullptr;
}

void IValueArray::SetValue(IBaseValue * value, int index)
{
	auto v8_array = GetV8Array();
	v8_array->Set(GetCurrentContext(), index, value->GetV8Value());
}

std::vector<v8::Local<v8::Value>> IValueArray::GeV8ValueVector()
{
	auto LocalArr = GetV8Array();
	auto ctx = GetCurrentContext();
	int vector_length = LocalArr->Length();
	std::vector<v8::Local<v8::Value>> vector_result(vector_length);
	for (int i = 0; i < vector_length; i++) {
		vector_result[i] = LocalArr->Get(ctx, i).ToLocalChecked();
	}
	return vector_result;
}

v8::Local<v8::Array> IValueArray::GetV8Array()
{
    return v8::Local<v8::Array>::Cast(GetV8Value());
}

IGetterArgs::IGetterArgs(const v8::PropertyCallbackInfo<v8::Value>& info, char * prop)
{
	IsIndexedProp = false;
	propinfo = &info;
	propName = prop;
	iso = info.GetIsolate();
}

IGetterArgs::IGetterArgs(const v8::PropertyCallbackInfo<v8::Value>& info, v8::Local<v8::Value> index)
{
    IsIndexedProp = true;
    propinfo = &info;
    iso = info.GetIsolate();
    indexValue = new IValue(iso, index, -1);
}

IGetterArgs::IGetterArgs(const v8::PropertyCallbackInfo<v8::Value>& info, int index)
{
	IsIndexedProp = true;
	propinfo = &info;
	propInd = index;
	iso = info.GetIsolate();
}

void * IGetterArgs::GetDelphiObject()
{
	IEngine * eng = IEngine::GetEngine(iso);
	if (!eng)
		return nullptr;
	auto holder = propinfo->Holder();
	return eng->GetDelphiObject(holder);
}

void * IGetterArgs::GetDelphiClasstype()
{
	IEngine * eng = IEngine::GetEngine(iso);
	if (!eng)
		return nullptr;
	auto holder = propinfo->Holder();
	return eng->GetDelphiClasstype(holder);
}

char * IGetterArgs::GetPropName()
{
	auto vec = std::vector<char>(propName.begin(), propName.end());
	run_string_result = vec;
	run_string_result.push_back(0);
	return run_string_result.data();
}

int IGetterArgs::GetPropIndex()
{
	return propInd;
}

IValue * IGetterArgs::GetPropIndexAsIValue()
{
    return indexValue;
}

void IGetterArgs::SetGetterResultUndefined()
{
	propinfo->GetReturnValue().SetUndefined();
}

void IGetterArgs::SetGetterResultIFace(void * value)
{
	v8::Isolate * iso = propinfo->GetIsolate();
	IEngine * eng = IEngine::GetEngine(iso);
	auto ctx = iso->GetCurrentContext();
	v8::Local<v8::Object> obj = eng->ifaceTemplate->NewInstance(ctx).ToLocalChecked();
	obj->SetInternalField(DelphiObjectIndex, v8::External::New(iso, value));
	propinfo->GetReturnValue().Set(obj);
}

void IGetterArgs::SetGetterResultAsInterfaceFunction(void * intf, char * funcName)
{
	v8::Isolate * iso = propinfo->GetIsolate();
	auto ctx = iso->GetCurrentContext();
	IEngine * eng = IEngine::GetEngine(iso);
	auto arr = v8::Array::New(iso, 0);
	////0 - interface pointer, 1 - function name
	arr->Set(ctx, 0, v8::External::New(iso, intf));
	arr->Set(ctx, 1, v8::String::NewFromUtf8(iso, funcName,v8::NewStringType::kNormal).ToLocalChecked());
	v8::Local<v8::FunctionTemplate> DelphiFuncTemplate = v8::FunctionTemplate::New(iso, eng->InterfaceFuncCallBack, 
		arr);
	auto func = DelphiFuncTemplate->GetFunction(ctx).ToLocalChecked();
	propinfo->GetReturnValue().Set(func);
}

void IGetterArgs::SetGetterResultDObject(void * value, void * dClasstype)
{
	v8::Isolate * iso = propinfo->GetIsolate();
	IEngine * eng = IEngine::GetEngine(iso);
	if (!eng->ClassIsRegistered(dClasstype)) {
		dClasstype = eng->GetRegisteredParentClasstype(dClasstype);
	}
	auto result = eng->FindObject(value, dClasstype, iso);
	if (!result.IsEmpty())
	{
		propinfo->GetReturnValue().Set(result);
	}
	else 
	{
		auto dTempl = eng->GetObjectByClass(dClasstype);
		if (dTempl) {
			auto ctx = iso->GetCurrentContext();
			auto obj = dTempl->objTempl->InstanceTemplate()->NewInstance(ctx).ToLocalChecked();
			obj->SetInternalField(DelphiObjectIndex, v8::External::New(iso, value));
			obj->SetInternalField(DelphiClassTypeIndex, v8::External::New(iso, dClasstype));
			eng->AddObject(value, dClasstype, obj, iso);
			propinfo->GetReturnValue().Set(obj);
		}
	}
}

void IGetterArgs::SetGetterResultInt(int val)
{
	propinfo->GetReturnValue().Set(v8::Integer::New(iso, val));
}

void IGetterArgs::SetGetterResultBool(bool val)
{
	propinfo->GetReturnValue().Set(val);
}

void IGetterArgs::SetGetterResultString(char * val)
{
	auto str = v8::String::NewFromUtf8(propinfo->GetIsolate(), val, v8::NewStringType::kNormal).ToLocalChecked();
	propinfo->GetReturnValue().Set<v8::String>(str);
}

void IGetterArgs::SetGetterResultDouble(double val)
{
	propinfo->GetReturnValue().Set(val);
}

void IGetterArgs::SetGetterResultAsIndexObject(void * parentObj, void * rttiProp)
{
	v8::Isolate * iso = propinfo->GetIsolate();
	IEngine * eng = IEngine::GetEngine(iso);
	auto result = eng->FindObject(parentObj, rttiProp, iso);
	if (!result.IsEmpty())
	{
		propinfo->GetReturnValue().Set(result);
        return;
	}
	auto dTempl = eng->indexedObjTemplate;
	if (!dTempl.IsEmpty()) {
		auto ctx = iso->GetCurrentContext();
		auto obj = dTempl->NewInstance(ctx).ToLocalChecked();
		obj->SetInternalField(DelphiObjectIndex, v8::External::New(iso, parentObj));
		obj->SetInternalField(DelphiClassTypeIndex, v8::External::New(iso, rttiProp));
		eng->AddObject(parentObj, rttiProp, obj, iso);
		propinfo->GetReturnValue().Set(obj);
	}
}

void IGetterArgs::SetGetterResult(IBaseValue * val)
{
    if (val)
        propinfo->GetReturnValue().Set(val->GetV8Value());
}

void IGetterArgs::SetError(char * errorMsg)
{
	error = errorMsg;
}

void * IGetterArgs::GetEngine()
{
	IEngine * engine = IEngine::GetEngine(iso);
	if (!engine)
		return nullptr;
	return engine->DEngine;
}

ISetterArgs::ISetterArgs(const v8::PropertyCallbackInfo<void>& info, char * prop, v8::Local<v8::Value> newValue)
{
	IsIndexedProp = false;
	propName = prop;
	propinfo = &info;
	iso = info.GetIsolate();
	newVal = newValue;
	setterVal = new IValue(iso, newVal, 0);
}

ISetterArgs::ISetterArgs(const v8::PropertyCallbackInfo<v8::Value>& info, v8::Local<v8::Value> index, v8::Local<v8::Value> newValue)
{
    IsIndexedProp = true;
    indexedPropInfo = &info;
    iso = info.GetIsolate();
    indexVal = new IValue(iso, index, -1);
    newVal = newValue;
    setterVal = new IValue(iso, newVal, 0);
}

ISetterArgs::ISetterArgs(const v8::PropertyCallbackInfo<v8::Value>& info, int index, v8::Local<v8::Value> newValue)
{
	IsIndexedProp = true;
	propInd = index;
	indexedPropInfo = &info;
	iso = info.GetIsolate();
	newVal = newValue;
	setterVal = new IValue(iso, newVal, 0);
}

void * ISetterArgs::GetEngine()
{
	IEngine * engine = IEngine::GetEngine(iso);
	if (!engine)
		return nullptr;
	return engine->DEngine;
}

void * ISetterArgs::GetDelphiObject()
{
	IEngine * eng = IEngine::GetEngine(iso);
	if (!eng)
		return nullptr;
	v8::Local<v8::Object> holder;
	if (IsIndexedProp) {
		holder = indexedPropInfo->Holder();
	}
	else {
		holder = propinfo->Holder();
	}
	return eng->GetDelphiObject(holder);
}

void * ISetterArgs::GetDelphiClasstype()
{
	IEngine * eng = IEngine::GetEngine(iso);
	if (!eng)
		return nullptr;
	v8::Local<v8::Object> holder;
	if (IsIndexedProp) {
		holder = indexedPropInfo->Holder();
	}
	else {
		holder = propinfo->Holder();
	}
	return eng->GetDelphiClasstype(holder);
}

char * ISetterArgs::GetPropName()
{
	auto vec = std::vector<char>(propName.begin(), propName.end());
	run_string_result = vec;
	run_string_result.push_back(0);
	return run_string_result.data();
}

int ISetterArgs::GetPropIndex()
{
	return propInd;
}

IValue * ISetterArgs::GetPropIndexAsIValue()
{
    return indexVal;
}

IValue * ISetterArgs::GetValue()
{
	return setterVal;
}

void * ISetterArgs::GetValueAsDObject()
{
	if (newVal->IsObject()) {
		auto objVal = newVal.As<v8::Object>();
		if (objVal->InternalFieldCount() > 0) {
			auto objField = objVal->GetInternalField(DelphiObjectIndex);
			if (objField->IsExternal())
				return objField.As<v8::External>()->Value();
		}

	}
	return nullptr;
}

int ISetterArgs::GetValueAsInt()
{
	return newVal->Int32Value(iso->GetCurrentContext()).FromMaybe(0);
}

bool ISetterArgs::GetValueAsBool()
{
	return newVal->BooleanValue(iso->GetCurrentContext()).FromMaybe(false);
}

char * ISetterArgs::GetValueAsString()
{
	v8::String::Utf8Value str(newVal);
	char *it1 = *str;
	char *it2 = *str + str.length();
	auto vec = std::vector<char>(it1, it2);
	run_string_result = vec;
	run_string_result.push_back(0);
	return run_string_result.data();
}

double ISetterArgs::GetValueAsDouble()
{
	return newVal->NumberValue(iso->GetCurrentContext()).FromMaybe(0.0);
}

void ISetterArgs::SetGetterResultUndefined()
{
	propinfo->GetReturnValue().SetUndefined();
}

void ISetterArgs::SetGetterResultIFace(void * value)
{
	v8::Isolate * iso = propinfo->GetIsolate();
	IEngine * eng = IEngine::GetEngine(iso);
	auto ctx = iso->GetCurrentContext();
	v8::Local<v8::Object> obj = eng->ifaceTemplate->NewInstance(ctx).ToLocalChecked();
	obj->SetInternalField(DelphiObjectIndex, v8::External::New(iso, value));
	propinfo->GetReturnValue().Set(obj);
}

void ISetterArgs::SetGetterResultAsInterfaceFunction(void * intf, char * funcName)
{
	v8::Isolate * iso = propinfo->GetIsolate();
	auto ctx = iso->GetCurrentContext();
	IEngine * eng = IEngine::GetEngine(iso);
	auto arr = v8::Array::New(iso, 0);
	////0 - interface pointer, 1 - function name
	arr->Set(ctx, 0, v8::External::New(iso, intf));
	arr->Set(ctx, 1, v8::String::NewFromUtf8(iso, funcName, v8::NewStringType::kNormal).ToLocalChecked());
	v8::Local<v8::FunctionTemplate> DelphiFuncTemplate = v8::FunctionTemplate::New(iso, eng->InterfaceFuncCallBack,
		arr);
	auto func = DelphiFuncTemplate->GetFunction(ctx).ToLocalChecked();
	propinfo->GetReturnValue().Set(func);
}

void ISetterArgs::SetGetterResultDObject(void * value, void * dClasstype)
{
	v8::Isolate * iso = propinfo->GetIsolate();
	IEngine * eng = IEngine::GetEngine(iso);
	if (!eng->ClassIsRegistered(dClasstype)) {
		dClasstype = eng->GetRegisteredParentClasstype(dClasstype);
	}
	auto result = eng->FindObject(value, dClasstype, iso);
	if (!result.IsEmpty())
	{
		propinfo->GetReturnValue().Set(result);
	}
	else
	{
		auto dTempl = eng->GetObjectByClass(dClasstype);
		if (dTempl) {
			auto ctx = iso->GetCurrentContext();
			auto obj = dTempl->objTempl->InstanceTemplate()->NewInstance(ctx).ToLocalChecked();
			obj->SetInternalField(DelphiObjectIndex, v8::External::New(iso, value));
			obj->SetInternalField(DelphiClassTypeIndex, v8::External::New(iso, dClasstype));
			eng->AddObject(value, dClasstype, obj, iso);
			propinfo->GetReturnValue().Set(obj);
		}
	}
}

void ISetterArgs::SetGetterResultInt(int val)
{
	propinfo->GetReturnValue().Set(v8::Integer::New(iso, val));
}

void ISetterArgs::SetGetterResultBool(bool val)
{
	propinfo->GetReturnValue().Set(val);
}

void ISetterArgs::SetGetterResultString(char * val)
{
	auto str = v8::String::NewFromUtf8(propinfo->GetIsolate(), val, v8::NewStringType::kNormal).ToLocalChecked();
	propinfo->GetReturnValue().Set<v8::String>(str);
}

void ISetterArgs::SetGetterResultDouble(double val)
{
	propinfo->GetReturnValue().Set(val);
}

void ISetterArgs::SetGetterResultAsIndexObject(void * parentObj, void * rttiProp)
{
	v8::Isolate * iso = propinfo->GetIsolate();
	IEngine * eng = IEngine::GetEngine(iso);
	auto result = eng->FindObject(parentObj, rttiProp, iso);
	if (!result.IsEmpty())
	{
		propinfo->GetReturnValue().Set(result);
	}
	auto dTempl = eng->indexedObjTemplate;
	if (!dTempl.IsEmpty()) {
		auto ctx = iso->GetCurrentContext();
		auto obj = dTempl->NewInstance(ctx).ToLocalChecked();
		obj->SetInternalField(DelphiObjectIndex, v8::External::New(iso, parentObj));
		obj->SetInternalField(DelphiClassTypeIndex, v8::External::New(iso, rttiProp));
		eng->AddObject(parentObj, rttiProp, obj, iso);
		propinfo->GetReturnValue().Set(obj);
	}

}

void ISetterArgs::SetGetterResult(IBaseValue * val)
{
    propinfo->GetReturnValue().Set(val->GetV8Value());
}

void ISetterArgs::SetError(char * errorMsg)
{
	error = errorMsg;
}

IRecord::IRecord(v8::Isolate * isolate): IBaseValue(isolate)
{
	v8::Local<v8::Object> localObj = v8::Object::New(isolate);
    SetV8Value(localObj);
}

IRecord::IRecord(v8::Isolate * isolate, v8::Local<v8::Object> localObj) : IBaseValue(isolate, localObj)
{
}

void IRecord::SetIntField(char * name, int val)
{
	auto object = GetV8Object();
	object->CreateDataProperty(GetCurrentContext(),
		v8::String::NewFromUtf8(Isolate(), name, v8::NewStringType::kNormal).ToLocalChecked(),
		v8::Integer::New(Isolate(), val));
}

void IRecord::SetDoubleField(char * name, double val)
{
	auto object = GetV8Object();
	object->Set(GetCurrentContext(), v8::String::NewFromUtf8(Isolate(), name, v8::NewStringType::kNormal).ToLocalChecked(),
		v8::Number::New(Isolate(), val));
}

void IRecord::SetBoolField(char * name, bool val)
{
	auto object = GetV8Object();
	object->CreateDataProperty(GetCurrentContext(),
		v8::String::NewFromUtf8(Isolate(), name, v8::NewStringType::kNormal).ToLocalChecked(),
		v8::Boolean::New(Isolate(), val));
}

void IRecord::SetStringField(char * name, char * val)
{
	auto object = GetV8Object();
	object->CreateDataProperty(GetCurrentContext(),
		v8::String::NewFromUtf8(Isolate(), name, v8::NewStringType::kNormal).ToLocalChecked(),
		v8::String::NewFromUtf8(Isolate(), val, v8::NewStringType::kNormal).ToLocalChecked());
}

void IRecord::SetObjectField(char * name, void * val)
{
	if (val){
		auto object = GetV8Object();
		object->CreateDataProperty(GetCurrentContext(),
			v8::String::NewFromUtf8(Isolate(), name, v8::NewStringType::kNormal).ToLocalChecked(),
			v8::External::New(Isolate(), val));
	}
}

void IRecord::SetValueField(char * name, IBaseValue * val)
{
    if (val) {
        auto object = GetV8Object();
        object->CreateDataProperty(GetCurrentContext(),
            v8::String::NewFromUtf8(Isolate(), name, v8::NewStringType::kNormal).ToLocalChecked(),
            val->GetV8Value());
    }
}

int IRecord::GetIntField(char * name)
{
	auto val = GetField(name);
	return val->Int32Value(GetCurrentContext()).FromMaybe(0);
}

double IRecord::GetDoubleField(char * name)
{
	auto val = GetField(name);
	return val->NumberValue(GetCurrentContext()).FromMaybe(0.0);
}

bool IRecord::GetBoolField(char * name)
{
    auto val = GetField(name);
	return val->BooleanValue(GetCurrentContext()).FromMaybe(false);
}

char * IRecord::GetStringField(char * name)
{
    auto val = GetField(name);
    run_string_result = std::vector<char>();
    v8::Isolate::Scope iso_scope(Isolate());
    auto maybeVal = val->ToString(GetCurrentContext());
    if (!maybeVal.IsEmpty()) {
        v8::String::Utf8Value str(maybeVal.ToLocalChecked());
        char *it1 = *str;
        char *it2 = *str + str.length();
        auto vec = std::vector<char>(it1, it2);
        run_string_result = vec;
        run_string_result.push_back(0);
    };
	return run_string_result.data();
}

void * IRecord::GetObjectField(char * name)
{
    auto val = GetField(name);
	if (val->IsExternal())
		return val.As<v8::External>()->Value();
	return nullptr;
}

v8::Local<v8::Object> IRecord::GetV8Object()
{
    return GetV8Value()->ToObject(GetCurrentContext()).ToLocalChecked();
}

v8::Local<v8::Value> IRecord::GetField(char * name)
{
    v8::Isolate::Scope iso_scope(Isolate());
    auto result = v8::Local<v8::Value>();
    auto object = GetV8Object();
    auto maybeVal = object->GetRealNamedProperty(GetCurrentContext(),
        v8::String::NewFromUtf8(Isolate(), name, v8::NewStringType::kNormal).ToLocalChecked());
    if (!maybeVal.IsEmpty())
        result = maybeVal.ToLocalChecked();
    return result;
}

IFunction::IFunction(v8::Local<v8::Function> function, v8::Isolate * isolate)
{
	iso = isolate;
	func.Reset(iso, function);
}

void IFunction::AddArgAsInt(int val)
{
	argv.push_back(v8::Integer::New(iso, val));
}

void IFunction::AddArgAsBool(bool val)
{
	argv.push_back(v8::Boolean::New(iso, val));
}

void IFunction::AddArgAsString(char * val)
{
	argv.push_back(v8::String::NewFromUtf8(iso, val, v8::NewStringType::kNormal).ToLocalChecked());
}

void IFunction::AddArgAsNumber(double val)
{
	argv.push_back(v8::Number::New(iso, val));
}

void IFunction::AddArgAsObject(void * value, void * classtype)
{
	IEngine * eng = IEngine::GetEngine(iso);
	if (!eng->ClassIsRegistered(classtype)) {
		classtype = eng->GetRegisteredParentClasstype(classtype);
	}
	auto result = eng->FindObject(value, classtype, iso);
	if (!result.IsEmpty()) {
		argv.push_back(result);
	}
	else {
		auto dTempl = eng->GetObjectByClass(classtype);
		if (dTempl) {
			auto ctx = iso->GetCurrentContext();
			auto maybeObj = dTempl->objTempl->InstanceTemplate()->NewInstance(ctx);
			auto obj = maybeObj.ToLocalChecked();
			obj->SetInternalField(DelphiObjectIndex, v8::External::New(iso, value));
			obj->SetInternalField(DelphiClassTypeIndex, v8::External::New(iso, classtype));
			argv.push_back(obj);
		}
	}
}

void IFunction::AsyncAction(uv_idle_t * handle)
{
    auto data = static_cast<AsyncFuncData *>(handle->data);
    auto iso = data->iso;
    if (iso) {
        //v8::Unlocker unlocker(iso);
        //v8::Locker locker(iso);
        v8::Isolate::Scope scope(iso);
        v8::HandleScope hScope(iso);
        v8::Persistent<v8::Function> func;
        func.Reset(iso, data->func.Get(iso));
        //auto func = data->func;
        auto returnVal = data->returnVal;
        auto argv = *(data->argv);

        auto res = func.Get(iso)->Call(iso->GetCurrentContext(), func.Get(iso), argv.size(), argv.data());
        if (!res.IsEmpty()) {
            returnVal = new IValue(iso, res.ToLocalChecked(), 0);
            argv.clear();
            data->returnVal = returnVal;
        }
        else {
            data->returnVal = nullptr;
        }
    }
    //uv_stop(handle->loop);
}

IValue * IFunction::CallFunction()
{
    //AsyncFuncData * data = new AsyncFuncData();
    //data->argv = &argv;
    ////data->func = func;
    //{
    //    v8::Isolate::Scope scope(iso);
    //    data->func.Reset(iso, func.Get(iso));
    //}
    //data->iso = iso;
    //if (returnVal)
    //    returnVal->Delete();
    //data->returnVal = returnVal;

    //uv_work_t * req = new uv_work_t();
    //req->data = data;
    //uv_loop_t * loop = static_cast<uv_loop_t *>(malloc(sizeof(uv_loop_t)));    
    //uv_loop_init(loop);
    //auto loop = uv_default_loop();

    //uv_idle_t idler;
    //idler.data = data;
    //uv_idle_init(loop, &idler);
    //uv_idle_start(&idler, AsyncAction);
    //
    //bool more;
    //do {
    //    more = uv_run(loop, UV_RUN_ONCE);

    //    if (more == false) {
    //        //EmitBeforeExit(env);

    //        // Emit `beforeExit` if the loop became alive either after emitting
    //        // event, or after running some callbacks.
    //        more = uv_loop_alive(loop);
    //        if (uv_run(loop, UV_RUN_NOWAIT) != 0)
    //            more = true;
    //    }
    //} while (more == true);
    //
    //uv_run(loop, UV_RUN_NOWAIT);
    //uv_stop(loop);
	v8::Isolate::Scope scope(iso);
	if (returnVal){
		returnVal->Delete();
		returnVal = nullptr;
	}
	auto res = func.Get(iso)->Call(iso->GetCurrentContext(), func.Get(iso), argv.size(), argv.data());
	if (!res.IsEmpty()) {
		returnVal = new IValue(iso, res.ToLocalChecked(), 0);
		argv.clear();
		return returnVal;
	}
	else
		return nullptr;
    //returnVal = data->returnVal;
    //uv_loop_close(loop);

    //TODO: call settimeout;
    return returnVal;
}

IIntfSetterArgs::IIntfSetterArgs(const v8::PropertyCallbackInfo<v8::Value>& info, char * prop, v8::Local<v8::Value> newValue)
{
	propName = prop;
	IntfPropInfo = &info;
	iso = info.GetIsolate();
	newVal = newValue;
	setterVal = new IValue(iso, newVal, 0);
}

void * IIntfSetterArgs::GetEngine()
{
	IEngine * engine = IEngine::GetEngine(iso);
	if (!engine)
		return nullptr;
	return engine->DEngine;
}

void * IIntfSetterArgs::GetDelphiObject()
{
	IEngine * eng = IEngine::GetEngine(iso);
	if (!eng)
		return nullptr;
	v8::Local<v8::Object> holder;
	holder = IntfPropInfo->Holder();
	return eng->GetDelphiObject(holder);
}

char * IIntfSetterArgs::GetPropName()
{
	auto vec = std::vector<char>(propName.begin(), propName.end());
	run_string_result = vec;
	run_string_result.push_back(0);
	return run_string_result.data();
}

IValue * IIntfSetterArgs::GetValue()
{
	return setterVal;
}

void * IIntfSetterArgs::GetValueAsDObject()
{
	if (newVal->IsObject()) {
		auto objVal = newVal.As<v8::Object>();
		if (objVal->InternalFieldCount() > 0) {
			auto objField = objVal->GetInternalField(DelphiObjectIndex);
			if (objField->IsExternal())
				return objField.As<v8::External>()->Value();
		}

	}
	return nullptr;
}

int IIntfSetterArgs::GetValueAsInt()
{
	return newVal->Int32Value(iso->GetCurrentContext()).FromMaybe(0);
}

bool IIntfSetterArgs::GetValueAsBool()
{
	return newVal->BooleanValue(iso->GetCurrentContext()).FromMaybe(false);
}

char * IIntfSetterArgs::GetValueAsString()
{
	v8::String::Utf8Value str(newVal);
	char *it1 = *str;
	char *it2 = *str + str.length();
	auto vec = std::vector<char>(it1, it2);
	run_string_result = vec;
	run_string_result.push_back(0);
	return run_string_result.data();
}

double IIntfSetterArgs::GetValueAsDouble()
{
	return newVal->NumberValue(iso->GetCurrentContext()).FromMaybe(0.0);
}

void IIntfSetterArgs::SetError(char * errorMsg)
{
	error = errorMsg;
}

IBaseValue::IBaseValue(v8::Isolate * isolate, v8::Local<v8::Value> value)
{
    iso = isolate;
    v8Value.Reset(isolate, value);
}

v8::Local<v8::Value> IBaseValue::GetV8Value()
{
    return v8Value.Get(iso);
}

void IBaseValue::SetV8Value(v8::Local<v8::Value> value)
{
    v8Value.Reset(iso, value);
}

v8::Isolate * IBaseValue::Isolate()
{
    return iso;
}

v8::Local<v8::Context> IBaseValue::GetCurrentContext()
{
    return iso->GetCurrentContext();
}

bool IBaseValue::IsObject()
{
    
    return !(dynamic_cast<IObject *>(this) == nullptr);
}

bool IBaseValue::IsRecord()
{
    return !(dynamic_cast<IRecord *>(this) == nullptr);
}

bool IBaseValue::IsArray()
{
    return !(dynamic_cast<IValueArray *>(this) == nullptr);
}

bool IBaseValue::IsValue()
{
    return !(dynamic_cast<IValue *>(this) == nullptr);
}

IObject * IBaseValue::AsObject()
{
    return dynamic_cast<IObject *>(this);
}

IValueArray * IBaseValue::AsArray()
{
    return dynamic_cast<IValueArray *>(this);
}

IRecord * IBaseValue::AsRecord()
{
    return dynamic_cast<IRecord *>(this);
}

IValue * IBaseValue::AsValue()
{
    return dynamic_cast<IValue *>(this);
}

}