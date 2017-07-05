let fs = require('fs');
let path = require('path');
const folder = '.\\test';
fs.readdir(folder, (err, files)=>{
    files.forEach(file=>{
        if (path.extname(file).toLowerCase() == '.js'){
            try{
                console.log(`test ${file} starts`);
                let text = fs.readFileSync(process.cwd() + '\\' + folder + '\\' + file, 'utf8');
                eval(text);
            }
            catch(e){
                console.log(`error: ${e.stack}`);
            }
            console.log(`test ${file} ends`);
            console.log('=================================');
        }
    })
});