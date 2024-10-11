
var stageWidth = window.innerWidth;
var stageHeight = window.innerHeight; /*Para que ocupe toda la ventana*/
var xRows = 25;
var zRows = 25;
var cubeSize = 300;
var cubeGap = 200;
var cubeRow = cubeSize + cubeGap;

var container = document.getElementById('container');

var camera = new THREE.PerspectiveCamera(55, stageWidth/stageHeight, 1, 20000);
camera.position.y = 5000;
camera.lookAt( new THREE.Vector3(0,0,0) );

var scene = new THREE.Scene();
scene.fog = new THREE.Fog( 0x000000, 5000, 10000 );

var pointLight = new THREE.PointLight(0x81d4fa);
pointLight.position.x = 0;
pointLight.position.y = 1800;
pointLight.position.z = -1800;
scene.add(pointLight);

group = new THREE.Object3D();
scene.add( group );

var cubes = [];

var halfXRows = (cubeRow * -xRows / 2);
var halfZRows = (cubeRow * -zRows / 2);

for (var x = 0; x < xRows; x++) {
  cubes[x] = []
  for (var z = 0; z < zRows; z++) { 
    var cubeHeight = 100 + Math.random() * 700;
    cubeHeight = 10 + (Math.sin(x / xRows * Math.PI) + Math.sin(z / zRows * Math.PI)) * 200 + Math.random() * 150;
    
    var geometry = new THREE.BoxGeometry(cubeSize, cubeHeight, cubeSize);

    
    var colours = [
        0x0d47a1, // Azul oscuro
        0x1976d2, // Azul medio
        0x42a5f5, // Azul claro
        0x81d4fa, // Celeste claro
        0xb3e5fc  // Celeste muy claro
    ];
    
    var material = new THREE.MeshPhongMaterial( {
      ambient: 0x81d4fa,
      color: colours[~~(Math.random() * colours.length)], 
      //color: ~~(Math.random() * 0xffffff), 
      specular: 0xffffff,
      shininess: 10, //~~(Math.random() * 200),
      shading: THREE.SmoothShading,
      transparent: true,
      opacity: 0.3
    } )

    var cube = new THREE.Mesh(geometry, material);
    cube.position.x = halfXRows + x * cubeRow;
    cube.position.y = cubeHeight / 2;
    cube.position.z = (cubeRow * -zRows / 2) + z * cubeRow;
    
    cube.height = cubeHeight;
    group.add(cube);
    
    cubes[x][z] = cube; 

  }
}



var renderer = new THREE.WebGLRenderer();
renderer.setSize(stageWidth, stageHeight);
container.appendChild( renderer.domElement );

var grid = { x: 0, z: 0};
var position = { x: 0, y: 0, z: 0};

function checkRow() {
  
  var xIndex = (position.x / cubeRow);    
  var xLoops = Math.floor(xIndex / xRows);

  var zIndex = (position.z / cubeRow);    
  var zLoops = Math.floor(zIndex / zRows);

  for (var x = 0; x < xRows; x++) {
    for (var z = 0; z < zRows; z++) {
    
      var dx, dz = 0;
      if ( x >= xIndex - xLoops * xRows ) {
        dx = xRows * (1 - xLoops);
      } else {
        dx = xRows * (0 - xLoops)
      }
      if ( z >= zIndex - zLoops * zRows ) {
        dz = zRows * (1 - zLoops);
      } else {
        dz = zRows * (0 - zLoops)
      }
      
     
      cubes[x][z].position.x = (x - dx) * cubeRow - halfXRows;
      cubes[x][z].position.z = (z - dz) * cubeRow - halfZRows
      
      var scale = (cubes[x][z].position.z + group.position.z) / 1500;
      if (scale < 1 ) scale = 1;
      scale = Math.pow(scale, 1.2);
      
      cubes[x][z].scale.y = scale;
      
      cubes[x][z].position.y = (cubes[x][z].height * scale) / 2;
      
    }
  }

}
var camPos = new THREE.Vector3(0,0,0);
var mouse = {x:0,y:0}
var isRunning = true;
function render(t) {
  if (isRunning) requestAnimationFrame( render );
  
  position.x += (Math.sin(t * 0.0001)) * 5;
  position.z += (Math.cos(t * 0.00003) + 5) * 5;
  group.position.x = -position.x;
  group.position.z = -position.z;
  
  
  checkRow();

  camera.position.x = Math.sin(t * 0.00003) * 1000;// + mouse.y;
  camera.position.z = -3500;
  camera.position.y = (Math.cos(t * 0.00005) + 1) * 1800;
  camera.lookAt(camPos);
  
  renderer.render( scene, camera );

}
render(0);

window.addEventListener("mousedown", function() {
  //isRunning = false;
})


window.addEventListener("mousemove", function(event) {
  mouse = event;
})


