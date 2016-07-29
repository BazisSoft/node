#include "delphi_intf.h"

#include <iostream>
#include <sstream>

namespace Bv8 {

BZINTF IEngine *BZDECL Bazis::InitEngine(void * DEngine)
{
	return new IEngine(DEngine);
}

BZINTF int BZDECL Bazis::GetEngineVersion()
{
	return 101;
}

uint32_t EngineSlot = 0;
// <<--Object internal fields' consts
int DelphiObjectIndex = 0;
int DelphiClassTypeIndex = 1;

int ObjectInternalFieldCount = 2;
// Object internal fields' consts-->>

bool IEngine::ReadScriptConsole()
{
	/*v8::Isolate::Scope isolate_scope(isolate);
	v8::HandleScope handle_scope(isolate);
	v8::Local<v8::Context> context = CreateShellContext();
	if (context.IsEmpty()) {
		fprintf(stderr, "Error creating context\n");
		return 1;
	}
	v8::Context::Scope context_scope(context);
	v8::Local<v8::String> name(
		v8::String::NewFromUtf8(isolate, "(shell)",
			v8::NewStringType::kNormal).ToLocalChecked());
	while (true) {
		static const int kBufferSize = 256;
		char buffer[kBufferSize];
		fprintf(stderr, "> ");
		char* str = fgets(buffer, kBufferSize, stdin);
		if (str == NULL) break;
		v8::HandleScope handle_scope(isolate);
		ExecuteString(v8::String::NewFromUtf8(isolate, str,
			v8::NewStringType::kNormal).ToLocalChecked(),
			true, name, true);
		while (v8::platform::PumpMessageLoop(platform, isolate))
			continue;
	}
	fprintf(stderr, "\n");*/
	return false;
}

std::vector<char> IEngine::ReadCode(char * code)
{
	if (code == nullptr)
		return std::vector<char>();
	v8::Isolate::Scope isolate_scope(isolate);
	v8::HandleScope handle_scope(isolate);
	//v8::Local<v8::Context> context = CreateShellContext();
	//v8::Context::Scope context_scope(context);
	v8::Local<v8::String> name(
		v8::String::NewFromUtf8(isolate, "(shell)",
			v8::NewStringType::kNormal).ToLocalChecked());
	//v8::HandleScope handle_scope(isolate);
	return RunString(v8::String::NewFromUtf8(isolate, code,
		v8::NewStringType::kNormal).ToLocalChecked(),
		true, name, true);
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

inline void IEngine::AddMethod(std::string methodName) {
	methods.push_back(methodName);
}

v8::Isolate * IEngine::GetIsolate()
{
	return nullptr;
}

std::vector<char *> IEngine::MakeArgs(char * codeParam, bool isFileName, int& argc)
{
	std::vector<char *> args;
	//static char* filename = name;
	args.push_back(name);
	argc = 1;
	static char* arg0 = "";
	static char* arg1 = "";
	static char* arg2 = "";
	if (DebugMode()) {
		arg0 = "--debug-brk";
		args.push_back(arg0);
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
			arg0 = "-e";
			args.push_back(arg0);
			argc++;
			arg1 = codeParam;
			args.push_back(arg1);
			argc++;
		}
	}
	//char* argv[] = {&filename[0], &arg0[0], &arg1[0], &arg2[0], NULL };
	//return argv;
	return args;
}

v8::Local<v8::FunctionTemplate> IEngine::AddV8ObjectTemplate(IObjectTemplate * obj)
{
	obj->objTempl.Empty();
	obj->FieldCount = ObjectInternalFieldCount;
	auto V8Object = v8::FunctionTemplate::New(isolate);
	for (auto &field : obj->fields) {
		V8Object->PrototypeTemplate()->SetAccessor(v8::String::NewFromUtf8(isolate, field.c_str(), v8::NewStringType::kNormal).ToLocalChecked(),
			FieldGetter, FieldSetter);
	}
	for (auto &prop : obj->props) {
		V8Object->PrototypeTemplate()->SetAccessor(v8::String::NewFromUtf8(isolate, prop->name.c_str(), v8::NewStringType::kNormal).ToLocalChecked(),
			prop->read? Getter : (v8::AccessorGetterCallback)0,
			prop->write? Setter : (v8::AccessorSetterCallback)0 );
	}

	auto inc = 0;
	for (auto &method : obj->methods) {
		v8::Local<v8::FunctionTemplate> methodCallBack = v8::FunctionTemplate::New(isolate, FuncCallBack, v8::External::New(isolate, method->call));
		V8Object->PrototypeTemplate()->Set(v8::String::NewFromUtf8(isolate, method->name.c_str(), v8::NewStringType::kNormal).ToLocalChecked(), methodCallBack);
	}
	if (obj->HasIndexedProps) {
		V8Object->PrototypeTemplate()->SetIndexedPropertyHandler(IndexedPropGetter, IndexedPropSetter);
	}
	V8Object->PrototypeTemplate()->SetInternalFieldCount(obj->FieldCount);
	obj->objTempl.Reset(isolate, V8Object);
	return V8Object;
}

void IEngine::InitNode(char * execPath)
{
	if (!node_initialized) {
		int argc = 0;
		name = execPath;
		auto argv = MakeArgs("", false, argc);
		node::InitIalize(argc, argv.data(), [this](int code) {this->SetErrorCode(code); });
		node_initialized = true;
	}
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


/*virtual IObjectTemplate * GetObject(char * classtype) {
return eng.GetObject(classtype);
};*/

inline char * IEngine::RunString(char * code, char * exeName) {
	int argc = 0;
	name = exeName;
	auto argv = MakeArgs(code, false, argc);
	//node::Start(argc, argv.data(), [this](int code) {this->SetErrorCode(code); }, this);
	node::RunScript(argc, argv.data(), [this](int code) {this->SetErrorCode(code); }, this);
	/*run_string_result = ReadCode(code);
	run_string_result.push_back(0);
	return run_string_result.data();*/
	return "1";
}

char * IEngine::RunFile(char * fName, char * exeName)
{
	int argc = 0;
	name = exeName;
	auto argv = MakeArgs(fName, true, argc);
	//node::Start(argc, argv.data(), [this](int code) {this->SetErrorCode(code); }, this);
	node::RunScript(argc, argv.data(), [this](int code) {this->SetErrorCode(code); }, this);
	return nullptr;
}

void IEngine::SetDebug(bool debug)
{
	debugMode = debug;
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

void IEngine::InitializeGlobal()
{
	//for debugging time 
	return;
	v8::HandleScope handle(isolate);
	v8::Local<v8::FunctionTemplate> global = v8::FunctionTemplate::New(isolate);

	for (auto &method : globalTemplate->methods) {
		v8::Local<v8::FunctionTemplate> methodCallBack = v8::FunctionTemplate::New(isolate, FuncCallBack, v8::External::New(isolate, method->call));
		global->PrototypeTemplate()->Set(
			v8::String::NewFromUtf8(isolate, method->name.c_str(), v8::NewStringType::kNormal).ToLocalChecked(),
			methodCallBack);
	}

	for (auto &prop : globalTemplate->props) {
		global->PrototypeTemplate()->SetAccessor(v8::String::NewFromUtf8(isolate, prop->name.c_str(), v8::NewStringType::kNormal).ToLocalChecked(), Getter);
	}

	for (auto &obj : objects) {
		auto V8Object = AddV8ObjectTemplate(obj.get());
		global->PrototypeTemplate()->Set(v8::String::NewFromUtf8(isolate, obj->classtype.c_str(), v8::NewStringType::kNormal).ToLocalChecked(), V8Object);
	}
	//glob.Reset(isolate, global);
	globalTemplate->objTempl.Reset(isolate, global);
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

void IEngine::SetIndexedPropGetterCallBack(TGetterCallBack callBack)
{
	IndPropGetterCall = callBack;
}

void IEngine::SetIndexedPropSetterCallBack(TSetterCallBack callBack)
{
	IndPropSetterCall = callBack;
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
	{//debug info (delete after understanding)-----
		v8::String::Utf8Value utf8str(obj->ToString(isolate->GetCurrentContext()).ToLocalChecked());
		v8::String::Utf8Value utf8str2(obj->ToDetailString(isolate->GetCurrentContext()).ToLocalChecked());
	}// -----debug info
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

v8::Local<v8::ObjectTemplate> IEngine::MakeGlobalTemplate(v8::Isolate * iso)
{
	//v8::HandleScope handle(isolate);
	isolate = iso;
	v8::Local<v8::FunctionTemplate> global = v8::FunctionTemplate::New(isolate);

	for (auto &method : globalTemplate->methods) {
		v8::Local<v8::FunctionTemplate> methodCallBack = v8::FunctionTemplate::New(isolate, FuncCallBack, v8::External::New(isolate, method->call));
		global->PrototypeTemplate()->Set(
			v8::String::NewFromUtf8(isolate, method->name.c_str(), v8::NewStringType::kNormal).ToLocalChecked(),
			methodCallBack);
	}

	for (auto &prop : globalTemplate->props) {
		global->PrototypeTemplate()->SetAccessor(v8::String::NewFromUtf8(isolate, prop->name.c_str(), v8::NewStringType::kNormal).ToLocalChecked(), Getter);
	}

	for (auto &obj : objects) {
		auto V8Object = AddV8ObjectTemplate(obj.get());
		//global->PrototypeTemplate()->Set(v8::String::NewFromUtf8(isolate, obj->classtype.c_str(), v8::NewStringType::kNormal).ToLocalChecked(), V8Object);
	}
	global->PrototypeTemplate()->SetInternalFieldCount(ObjectInternalFieldCount);
	return global->PrototypeTemplate();
}

IEngine::IEngine(void * DEngine)
{
	//v8::V8::InitializeICU();
	//v8::V8::InitializeExternalStartupData(R"(D:\V8Engine\Win32\Debug\)");
	//platform = v8::platform::CreateDefaultPlatform();
	//v8::V8::InitializePlatform(platform);
	//v8::V8::Initialize();

	//std::string params = R"(D:\V8Engine\Win32\Debug\)";
	//v8::V8::SetFlagsFromString(params.data(), params.size());

	////
	//auto array_buffer_allocator = new ShellArrayBufferAllocator();

	//v8::Isolate::CreateParams create_params;
	//create_params.array_buffer_allocator = array_buffer_allocator;
	//isolate = v8::Isolate::New(create_params);
	//v8::HandleScope scoope(isolate);
	//isolate->SetData(EngineSlot, this);
	this->DEngine = DEngine;
	node_initialized = false;
}

IEngine::IEngine(int argc, char * argv[])
{
	v8::V8::InitializeICU();
	v8::V8::InitializeExternalStartupData(R"(D:\V8Engine\Win32\Debug\)");
	auto platform = v8::platform::CreateDefaultPlatform();
	v8::V8::InitializePlatform(platform);
	v8::V8::Initialize();
	v8::V8::SetFlagsFromCommandLine(&argc, argv, true);

	//
	auto array_buffer_allocator = new ShellArrayBufferAllocator();

	v8::Isolate::CreateParams create_params;
	create_params.array_buffer_allocator = array_buffer_allocator;
	isolate = v8::Isolate::New(create_params);
}

IEngine::~IEngine()
{
	if (node_initialized)
		node::Dispose();
	/*isolate->Dispose();
	v8::V8::Dispose();
	v8::V8::ShutdownPlatform();*/
	//delete platform;
}

void IEngine::ReportException(v8::Isolate* isolate, v8::TryCatch* try_catch) {
	v8::HandleScope handle_scope(isolate);
	v8::String::Utf8Value exception(try_catch->Exception());
	const char* exception_string = "";//ToCString(exception);
	v8::Local<v8::Message> message = try_catch->Message();
	if (message.IsEmpty()) {
		// V8 didn't provide any extra information about this error; just
		// print the exception.
		//fprintf(stderr, "%s\n", exception_string);
		std::cout << exception_string << "\n";
	}
	else {
		// Print (filename):(line number): (message).
		v8::String::Utf8Value filename(message->GetScriptOrigin().ResourceName());
		v8::Local<v8::Context> context(isolate->GetCurrentContext());
		const char* filename_string = "";// ToCString(filename);
		int linenum = message->GetLineNumber(context).FromJust();
		//fprintf(stderr, "%s:%i: %s\n", filename_string, linenum, exception_string);
		std::cout << filename_string << ':' << linenum << ':' << exception_string << "\n";
		// Print line of source code.
		v8::String::Utf8Value sourceline(
			message->GetSourceLine(context).ToLocalChecked());
		const char* sourceline_string = "";// ToCString(sourceline);
		//fprintf(stderr, "%s\n", sourceline_string);
		std::cout << sourceline_string << "\n";
		// Print wavy underline (GetUnderline is deprecated).
		int start = message->GetStartColumn(context).FromJust();
		for (int i = 0; i < start; i++) {
			//fprintf(stderr, " ");
			std::cout << " ";
		}
		int end = message->GetEndColumn(context).FromJust();
		for (int i = start; i < end; i++) {
			//fprintf(stderr, "^");
			std::cout << "^";
		}
		//fprintf(stderr, "\n");
		std::cout << "\n";
		v8::Local<v8::Value> stack_trace_string;
		if (try_catch->StackTrace(context).ToLocal(&stack_trace_string) &&
			stack_trace_string->IsString() &&
			v8::Local<v8::String>::Cast(stack_trace_string)->Length() > 0) {
			v8::String::Utf8Value stack_trace(stack_trace_string);
			const char* stack_trace_string = "";// ToCString(stack_trace);
			//fprintf(stderr, "%s\n", stack_trace_string);
			std::cout << stack_trace_string << "\n";
		}
	}
}

v8::Local<v8::Context> IEngine::CreateShellContext() {
	InitializeGlobal();
	auto global = glob.Get(isolate);
	global->PrototypeTemplate()->SetInternalFieldCount(ObjectInternalFieldCount);
	v8::Local<v8::Context> context = v8::Context::New(isolate, NULL, global->PrototypeTemplate());
	int globFieldCount = context->Global()->InternalFieldCount();
	int globFieldCount2 = context->Global()->GetPrototype()->ToObject(context).ToLocalChecked()->InternalFieldCount();
	auto globalObject = context->Global()->GetPrototype()->ToObject(context).ToLocalChecked(); //glob.Get(isolate)->NewInstance(isolate->GetCurrentContext()).ToLocalChecked();
	globalObject->SetInternalField(DelphiObjectIndex, v8::External::New(isolate, globObject));
	globalObject->SetInternalField(DelphiClassTypeIndex, v8::External::New(isolate, globalTemplate->DClass));
	return context;
}

void IEngine::IndexedPropGetter(unsigned int index, const v8::PropertyCallbackInfo<v8::Value>& info)
{
	IEngine * engine = static_cast<IEngine*>(info.GetIsolate()->GetData(EngineSlot));
	////TODO: call CAllBack;
	if (engine->IndPropGetterCall) {
		auto getterArgs = new IGetterArgs(info, index);
		engine->IndPropGetterCall(getterArgs);
	}
}

void IEngine::IndexedPropSetter(unsigned int index, v8::Local<v8::Value> value, const v8::PropertyCallbackInfo<v8::Value>& info)
{
	IEngine * engine = static_cast<IEngine*>(info.GetIsolate()->GetData(EngineSlot));
	////TODO: call CAllBack;
	if (engine->IndPropSetterCall) {
		auto setterArgs = new ISetterArgs(info, index, value);
		engine->IndPropSetterCall(setterArgs);
	}
}

void IEngine::FieldGetter(v8::Local<v8::String> property, const v8::PropertyCallbackInfo<v8::Value>& info)
{
	IEngine * engine = static_cast<IEngine*>(info.GetIsolate()->GetData(EngineSlot));
	////TODO: call CAllBack;
	if (engine->fieldGetterCall) {
		v8::String::Utf8Value str(property);
		auto getterArgs = new IGetterArgs(info, *str);
		engine->fieldGetterCall(getterArgs);
	}
}

void IEngine::FieldSetter(v8::Local<v8::String> property, v8::Local<v8::Value> value, const v8::PropertyCallbackInfo<void>& info)
{
	IEngine * engine = static_cast<IEngine*>(info.GetIsolate()->GetData(EngineSlot));
	////TODO: call CAllBack;
	if (engine->fieldSetterCall) {
		v8::String::Utf8Value str(property);
		auto setterArgs = new ISetterArgs(info, *str, value);
		engine->fieldSetterCall(setterArgs);
	}
}

void IEngine::Getter(v8::Local<v8::String> property, const v8::PropertyCallbackInfo<v8::Value>& info)
{
	IEngine * engine = static_cast<IEngine*>(info.GetIsolate()->GetData(EngineSlot));
	if (engine->getterCall) {
		v8::String::Utf8Value str(property);
		auto getterArgs = new IGetterArgs(info, *str);
		engine->getterCall(getterArgs);
	}
}

void IEngine::Setter(v8::Local<v8::String> property, v8::Local<v8::Value> value, const v8::PropertyCallbackInfo<void>& info)
{
	IEngine * engine = static_cast<IEngine*>(info.GetIsolate()->GetData(EngineSlot));
	////TODO: call CAllBack;
	if (engine->setterCall) {
		v8::String::Utf8Value str(property);
		auto setterArgs = new ISetterArgs(info, *str, value);
		engine->setterCall(setterArgs);
	}
}

void IEngine::FuncCallBack(const v8::FunctionCallbackInfo<v8::Value>& args)
{
	IEngine * engine = static_cast<IEngine*>(v8::Isolate::GetCurrent()->GetData(EngineSlot));
	if (engine->methodCall) {
		auto methodArgs = new IMethodArgs(args);
		engine->methodCall(methodArgs);
	}
}


bool IEngine::ExecuteString(v8::Local<v8::String> source, bool print_result,
	v8::Local<v8::Value> name, bool report_exceptions) {
	v8::HandleScope handle_scope(isolate);
	v8::TryCatch try_catch(isolate);
	v8::ScriptOrigin origin(name);
	v8::Local<v8::Context> context(isolate->GetCurrentContext());
	v8::Local<v8::Script> script;
	if (!v8::Script::Compile(context, source, &origin).ToLocal(&script)) {
		// Print errors that happened during compilation.
		if (report_exceptions)
			ReportException(isolate, &try_catch);
		return false;
	}
	else {
		v8::Local<v8::Value> result;
		if (!script->Run(context).ToLocal(&result)) {
			assert(try_catch.HasCaught());
			// Print errors that happened during execution.
			if (report_exceptions)
				ReportException(isolate, &try_catch);
			return false;
		}
		else {
			assert(!try_catch.HasCaught());
			if (print_result && !result->IsUndefined()) {
				// If all went well and the result wasn't undefined then print
				// the returned value.
				v8::String::Utf8Value str(result);
				const char* cstr = "";// ToCString(str);
				printf("%s\n", cstr);
			}
			return true;
		}
	}
}

std::vector<char> IEngine::RunString(v8::Local<v8::String> source, bool print_result, v8::Local<v8::Value> name, bool report_exceptions)
{
	v8::HandleScope handle_scope(isolate);
	v8::TryCatch try_catch(isolate);
	v8::ScriptOrigin origin(name);
	auto context = CreateShellContext();
	v8::Context::Scope context_scope(context);
	//for debug>>>>>>>>>

	//<<<<<<<<<for debug
	v8::Local<v8::Script> script;
	if (!v8::Script::Compile(context, source, &origin).ToLocal(&script)) {
		// Print errors that happened during compilation.
		if (report_exceptions)
			ReportException(isolate, &try_catch);
	}
	else {
		v8::Local<v8::Value> result;
		if (!script->Run(context).ToLocal(&result)) {
			assert(try_catch.HasCaught());
			// Print errors that happened during execution.
			if (report_exceptions)
				ReportException(isolate, &try_catch);
		}
		else {
			assert(!try_catch.HasCaught());
			if (print_result && !result->IsUndefined()) {
				// If all went well and the result wasn't undefined then print
				// the returned value.
				v8::String::Utf8Value str(result);
				char *it1 = *str;
				char *it2 = *str + str.length();
				auto vec = std::vector<char>(it1, it2);
				return vec;
			}
		}
	}
	if (try_catch.HasCaught()) {
		v8::String::Utf8Value str(try_catch.Exception());
		char *it1 = *str;
		char *it2 = *str + str.length();
		auto vec = std::vector<char>(it1, it2);
		return vec;
	}
	return std::vector<char>();
}

inline void IObjectTemplate::SetMethod(char * methodName, void * methodCall) {
	auto method = std::make_unique<IObjectMethod>();
	method->name = methodName;
	method->call = methodCall;
	methods.push_back(std::move(method));
}

inline void IObjectTemplate::SetProp(char * propName, bool read, bool write) {
	auto newProp = std::make_unique<IObjectProp>(propName, read, write);
	props.push_back(std::move(newProp));
}

void IObjectTemplate::SetField(char * fieldName)
{
	fields.push_back(fieldName);
}

void IObjectTemplate::SetHasIndexedProps(bool hasIndProps)
{
	HasIndexedProps = hasIndProps;
}

inline void IObjectTemplate::SetClasstype(char * classtype) { classtype = classtype; }

char * IObjectTemplate::GetClasstype()
{
	runStringResult = std::vector<char>(classtype.length(), *(classtype.c_str()));
	return runStringResult.data();
}

void IObjectTemplate::SetParent(IObjectTemplate * parent)
{
}

IObjectTemplate::IObjectTemplate(std::string objclasstype, v8::Isolate * isolate)
{
	classtype = objclasstype;
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

inline IObjectProp::IObjectProp(std::string pName, bool pRead, bool Pwrite) { name = pName; read = pRead; write = Pwrite; }

inline IObjectProp::IObjectProp() {}

//show arg's classtype by index

inline bool IValue::ArgIsNumber() {
	return v8Value.Get(isolate)->IsNumber();
}

bool IValue::ArgIsInt()
{
	return v8Value.Get(isolate)->IsInt32();
}

inline bool IValue::ArgIsBool() {
	return v8Value.Get(isolate)->IsBoolean();
}

inline bool IValue::ArgIsString() {
	return v8Value.Get(isolate)->IsString();
}

bool IValue::ArgIsObject()
{
	return v8Value.Get(isolate)->IsObject();
}
bool IValue::ArgIsArray()
{
	return v8Value.Get(isolate)->IsArray();
}
bool IValue::ArgIsV8Function()
{
	return v8Value.Get(isolate)->IsFunction();
}
//get arg by index

inline double IValue::GetArgAsNumber() {
	return v8Value.Get(isolate)->Int32Value(isolate->GetCurrentContext()).FromMaybe(0);
}

int IValue::GetArgAsInt()
{
	return v8Value.Get(isolate)->Int32Value(isolate->GetCurrentContext()).FromMaybe(0);
}

inline bool IValue::GetArgAsBool() {
	return v8Value.Get(isolate)->BooleanValue(isolate->GetCurrentContext()).FromMaybe(false);
}

inline char * IValue::GetArgAsString() {
	v8::String::Utf8Value str(v8Value.Get(isolate));
	char *it1 = *str;
	char *it2 = *str + str.length();
	auto vec = std::vector<char>(it1, it2);
	run_string_result = vec;
	run_string_result.push_back(0);
	return run_string_result.data();
}

IObject * IValue::GetArgAsObject()
{
	if (!obj) {
		obj = new IObject(isolate, v8Value.Get(isolate)->ToObject(isolate->GetCurrentContext()).ToLocalChecked());
	}
	return obj;
}

IArrayValues * IValue::GetArgAsArray()
{
	if (arr = nullptr)
	arr = new IArrayValues(isolate, v8::Local<v8::Array>::Cast(v8Value.Get(isolate)));
	return arr;
}

IRecord * IValue::GetArgAsRecord()
{
	if (!rec) {
		if (v8Value.Get(isolate)->IsExternal())
			rec = static_cast<IRecord *>(v8Value.Get(isolate).As<v8::External>()->Value());
		else
			rec = new IRecord(isolate, v8Value.Get(isolate)->ToObject(isolate->GetCurrentContext()).ToLocalChecked());
	};
	return rec;
}

IFunction * IValue::GetArgAsFunction()
{
	if (!func) {
		func = new IFunction(v8Value.Get(isolate).As<v8::Function>(), isolate);
	}
	return func;
}

int IValue::GetIndex()
{
	return ind;
}

IValue::IValue(v8::Isolate * iso, v8::Local<v8::Value> val, int index)
{
	isolate = iso;
	ind = index;
	v8Value.Reset(iso, val);
}

void * IMethodArgs::GetDelphiObject()
{
	IEngine * eng = static_cast<IEngine*>(iso->GetData(EngineSlot));
	auto holder = args->Holder();
	return eng->GetDelphiObject(holder);
}

void * IMethodArgs::GetDelphiClasstype()
{
	IEngine * eng = static_cast<IEngine*>(iso->GetData(EngineSlot));
	auto holder = args->Holder(); // args->This() will give the same object (for global, at least)
	return eng->GetDelphiClasstype(holder);
}

inline int IMethodArgs::GetArgsCount() {
	return args->Length();
}

inline char * IMethodArgs::GetMethodName() {
	v8::Isolate * iso = args->GetIsolate();
	std::string result = "";
	//args->Callee()->GetNAme(); -- this is name of calling method
	v8::String::Utf8Value str(args->Callee()->GetName());
	char *it1 = *str;
	char *it2 = *str + str.length();
	auto vec = std::vector<char>(it1, it2);
	result += vec.data();
	result += "\n";
	run_string_result = vec;
	run_string_result.push_back(0);
	return run_string_result.data();
}

void IMethodArgs::SetReturnValueClass(void * value, void* dClasstype)
{
	v8::Isolate * iso = args->GetIsolate();
	IEngine * eng = static_cast<IEngine*>(iso->GetData(EngineSlot));
	auto dTempl = eng->GetObjectByClass(dClasstype);
	if (dTempl) {
		auto ctx = iso->GetCurrentContext();
		auto maybeObj = dTempl->objTempl.Get(iso)->PrototypeTemplate()->NewInstance(ctx);
		auto obj = maybeObj.ToLocalChecked();
		obj->SetInternalField(DelphiObjectIndex, v8::External::New(iso, value));
		obj->SetInternalField(DelphiClassTypeIndex, v8::External::New(iso, dClasstype));
		args->GetReturnValue().Set(obj);
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

void IMethodArgs::SetReturnValueAsRecord()
{
	args->GetReturnValue().Set<v8::Object>(recVal->obj.Get(iso));
}

IRecord * IMethodArgs::GetReturnValueAsRecord()
{
	if (!recVal) {
		recVal = new IRecord(iso);
	}
	return recVal;
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

void * IMethodArgs::GetEngine()
{
	IEngine * engine = static_cast<IEngine*>(args->GetIsolate()->GetData(EngineSlot));
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

inline void * ArrayBufferAllocator::Allocate(size_t length) {
	void* data = AllocateUninitialized(length);
	return data == NULL ? data : memset(data, 0, length);
}

inline void * ArrayBufferAllocator::AllocateUninitialized(size_t length) { return malloc(length); }

inline void ArrayBufferAllocator::Free(void * data, size_t) { free(data); }

inline void * ShellArrayBufferAllocator::Allocate(size_t length) {
	void* data = AllocateUninitialized(length);
	return data == NULL ? data : memset(data, 0, length);
}

inline void * ShellArrayBufferAllocator::AllocateUninitialized(size_t length) { return malloc(length); }

inline void ShellArrayBufferAllocator::Free(void * data, size_t) { free(data); }

IObject::IObject(v8::Isolate * isolate, v8::Local<v8::Object> object)
{
	iso = isolate;
	obj.Reset(iso, object);
	isDObject = (object->InternalFieldCount() > 0 ? object->GetInternalField(DelphiObjectIndex)->IsExternal() : false);
}

bool IObject::IsDelphiObject()
{
	return isDObject;
}

void * IObject::GetDelphiObject()
{
	if (isDObject) {
		 auto objField = obj.Get(iso)->GetInternalField(DelphiObjectIndex);
		 if (objField->IsExternal())
			 return objField.As<v8::External>()->Value();
	}
	return nullptr;
}

void * IObject::GetDelphiClasstype()
{
	if (isDObject) {
		auto objField = obj.Get(iso)->GetInternalField(DelphiClassTypeIndex);
		if (objField->IsExternal())
			return objField.As<v8::External>()->Value();
	}
	return nullptr;
}

IArrayValues::IArrayValues(v8::Isolate * isolate , v8::Local<v8::Array> values_arr)
{
	iso = isolate;
	arr.Reset(isolate, values_arr);
	for (uint32_t i = 0; i < values_arr->Length(); i++) {
		auto val = std::make_unique<IValue>(iso, values_arr->Get(iso->GetCurrentContext(), i).ToLocalChecked(), i);
		values.push_back(std::move(val));
	}
}

int IArrayValues::GetCount()
{
	return arr.Get(iso)->Length();
}

IValue * IArrayValues::GetValue(int index)
{
	for (auto &val : values) {
		if (val->GetIndex() == index)
			return val.get();
	}
	return nullptr;
}

IGetterArgs::IGetterArgs(const v8::PropertyCallbackInfo<v8::Value>& info, char * prop)
{
	IsIndexedProp = false;
	propinfo = &info;
	propName = prop;
	iso = info.GetIsolate();
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
	IEngine * eng = static_cast<IEngine*>(iso->GetData(EngineSlot));
	auto holder = propinfo->Holder();
	return eng->GetDelphiObject(holder);
}

void * IGetterArgs::GetDelphiClasstype()
{
	IEngine * eng = static_cast<IEngine*>(iso->GetData(EngineSlot));
	auto holder = propinfo->Holder(); // propinfo->This() will give the same object (for global, at least)
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

void IGetterArgs::SetGetterResultDObject(void * value, void * dClasstype)
{
	v8::Isolate * iso = propinfo->GetIsolate();
	IEngine * eng = static_cast<IEngine*>(iso->GetData(EngineSlot));
	auto dTempl = eng->GetObjectByClass(dClasstype);
	if (dTempl) {
		auto ctx = iso->GetCurrentContext();
		auto maybeObj = dTempl->objTempl.Get(iso)->PrototypeTemplate()->NewInstance(ctx);
		auto obj = maybeObj.ToLocalChecked();
		obj->SetInternalField(DelphiObjectIndex, v8::External::New(iso, value));
		obj->SetInternalField(DelphiClassTypeIndex, v8::External::New(iso, dClasstype));
		propinfo->GetReturnValue().Set(obj);
	}
}

void IGetterArgs::SetGetterResultInt(int val)
{
	propinfo->GetReturnValue().Set(val);
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

void IGetterArgs::SetGetterResultAsRecord()
{
	propinfo->GetReturnValue().Set<v8::Object>(recVal->obj.Get(iso));
}

IRecord * IGetterArgs::GetGetterResultAsRecord()
{
	if (!recVal) {
		recVal = new IRecord(iso);
	}
	return recVal;
}

void * IGetterArgs::GetEngine()
{
	IEngine * engine = static_cast<IEngine*>(v8::Isolate::GetCurrent()->GetData(EngineSlot));
	return engine->DEngine;
}

ISetterArgs::ISetterArgs(const v8::PropertyCallbackInfo<void>& info, char * prop, v8::Local<v8::Value> newValue)
{
	IsIndexedProp = false;
	propName = prop;
	propinfo = &info;
	iso = info.GetIsolate();
	newVal.Reset(info.GetIsolate(), newValue);
	setterVal = new IValue(iso, newVal.Get(iso), 0);
}

ISetterArgs::ISetterArgs(const v8::PropertyCallbackInfo<v8::Value>& info, int index, v8::Local<v8::Value> newValue)
{
	IsIndexedProp = true;
	propInd = index;
	indexedPropInfo = &info;
	iso = info.GetIsolate();
	newVal.Reset(info.GetIsolate(), newValue);
	setterVal = new IValue(iso, newVal.Get(iso), 0);
}

void * ISetterArgs::GetEngine()
{
	IEngine * engine = static_cast<IEngine*>(iso->GetData(EngineSlot));
	return engine->DEngine;
}

void * ISetterArgs::GetDelphiObject()
{
	IEngine * eng = static_cast<IEngine*>(iso->GetData(EngineSlot));
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
	IEngine * eng = static_cast<IEngine*>(iso->GetData(EngineSlot));
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

IValue * ISetterArgs::GetValue()
{
	return setterVal;
}

void * ISetterArgs::GetValueAsDObject()
{
	if (newVal.Get(iso)->IsObject()) {
		auto objVal = newVal.Get(iso).As<v8::Object>();
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
	return newVal.Get(iso)->Int32Value(iso->GetCurrentContext()).FromMaybe(0);
}

bool ISetterArgs::GetValueAsBool()
{
	return newVal.Get(iso)->BooleanValue(iso->GetCurrentContext()).FromMaybe(false);
}

char * ISetterArgs::GetValueAsString()
{
	v8::String::Utf8Value str(newVal.Get(iso));
	char *it1 = *str;
	char *it2 = *str + str.length();
	auto vec = std::vector<char>(it1, it2);
	run_string_result = vec;
	run_string_result.push_back(0);
	return run_string_result.data();
}

double ISetterArgs::GetValueAsDouble()
{
	return newVal.Get(iso)->NumberValue(iso->GetCurrentContext()).FromMaybe(0.0);
}

IRecord::IRecord(v8::Isolate * isolate)
{
	iso = isolate;
	v8::Local<v8::Object> localObj = v8::Object::New(iso);
	obj.Reset(iso, localObj);
}

IRecord::IRecord(v8::Isolate * isolate, v8::Local<v8::Object> localObj)
{
	iso = isolate;
	obj.Reset(iso, localObj);
}

void IRecord::SetIntField(char * name, int val)
{
	auto object = obj.Get(iso);
	object->CreateDataProperty(iso->GetCurrentContext(),
		v8::String::NewFromUtf8(iso, name, v8::NewStringType::kNormal).ToLocalChecked(),
		v8::Integer::New(iso, val));
}

void IRecord::SetDoubleField(char * name, double val)
{
	auto object = obj.Get(iso);
	object->Set(iso->GetCurrentContext(), v8::String::NewFromUtf8(iso, name, v8::NewStringType::kNormal).ToLocalChecked(),
		v8::Number::New(iso, val));
}

void IRecord::SetBoolField(char * name, bool val)
{
	auto object = obj.Get(iso);
	object->CreateDataProperty(iso->GetCurrentContext(),
		v8::String::NewFromUtf8(iso, name, v8::NewStringType::kNormal).ToLocalChecked(),
		v8::Boolean::New(iso, val));
}

void IRecord::SetStringField(char * name, char * val)
{
	auto object = obj.Get(iso);
	object->CreateDataProperty(iso->GetCurrentContext(),
		v8::String::NewFromUtf8(iso, name, v8::NewStringType::kNormal).ToLocalChecked(),
		v8::String::NewFromUtf8(iso, val, v8::NewStringType::kNormal).ToLocalChecked());
}

void IRecord::SetObjectField(char * name, void * val)
{
	auto object = obj.Get(iso);
	object->CreateDataProperty(iso->GetCurrentContext(),
		v8::String::NewFromUtf8(iso, name, v8::NewStringType::kNormal).ToLocalChecked(),
		v8::External::New(iso, val));
}

int IRecord::GetIntField(char * name)
{
	auto object = obj.Get(iso);
	auto val = object->GetRealNamedProperty(iso->GetCurrentContext(),
		v8::String::NewFromUtf8(iso, name, v8::NewStringType::kNormal).ToLocalChecked()).ToLocalChecked();
	return val->Int32Value(iso->GetCurrentContext()).FromMaybe(0);
}

double IRecord::GetDoubleField(char * name)
{
	auto object = obj.Get(iso);
	auto val = object->GetRealNamedProperty(iso->GetCurrentContext(),
		v8::String::NewFromUtf8(iso, name, v8::NewStringType::kNormal).ToLocalChecked()).ToLocalChecked();
	return val->NumberValue(iso->GetCurrentContext()).FromMaybe(0.0);
}

bool IRecord::GetBoolField(char * name)
{
	auto object = obj.Get(iso);
	auto val = object->GetRealNamedProperty(iso->GetCurrentContext(),
		v8::String::NewFromUtf8(iso, name, v8::NewStringType::kNormal).ToLocalChecked()).ToLocalChecked();
	return val->BooleanValue(iso->GetCurrentContext()).FromMaybe(false);
}

char * IRecord::GetStringField(char * name)
{
	auto object = obj.Get(iso);
	auto val = object->GetRealNamedProperty(iso->GetCurrentContext(),
		v8::String::NewFromUtf8(iso, name, v8::NewStringType::kNormal).ToLocalChecked()).ToLocalChecked();
	v8::String::Utf8Value str(val->ToString(iso->GetCurrentContext()).ToLocalChecked());
	char *it1 = *str;
	char *it2 = *str + str.length();
	auto vec = std::vector<char>(it1, it2);
	run_string_result = vec;
	run_string_result.push_back(0);
	return run_string_result.data();
}

void * IRecord::GetObjectField(char * name)
{
	auto object = obj.Get(iso);
	auto val = object->GetRealNamedProperty(iso->GetCurrentContext(),
		v8::String::NewFromUtf8(iso, name, v8::NewStringType::kNormal).ToLocalChecked()).ToLocalChecked();
	if (val->IsExternal())
		return val.As<v8::External>()->Value();
	return nullptr;
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

void IFunction::AddArgAsObject(void * obj)
{
	argv.push_back(v8::External::New(iso, obj));
}

IValue * IFunction::CallFunction()
{
	if (returnVal)
		returnVal->Delete();
	returnVal = new IValue(iso, func.Get(iso)->Call(iso->GetCurrentContext(), func.Get(iso), argv.size(), argv.data()).ToLocalChecked(), 0);
	return returnVal;
}

}
