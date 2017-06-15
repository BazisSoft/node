const eps = 0.0001
v = NewVector();
v.x = 3;
v.y = 12;
v.z = 4;
console.assert(Math.abs(Length({ x: 3, y: 12, z: 4 }) - Length(v)) < eps);