import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';

const BED_SIZE = 180; // Bambu Lab A1 mini, millimeters
const GRID_STEP = 10;
const PLAIN_COLOR = 0xb9b6ae;

export class Preview {
  constructor(canvas) {
    this.renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true });
    this.renderer.setPixelRatio(window.devicePixelRatio);
    this.scene = new THREE.Scene();
    this.camera = new THREE.PerspectiveCamera(35, 1, 1, 5000);
    this.camera.up.set(0, 0, 1);
    this.controls = new OrbitControls(this.camera, canvas);
    this.controls.addEventListener('change', () => this.render());
    this.parts = new THREE.Group();
    this.scene.add(this.parts, this.bed(), ...this.lights());
    new ResizeObserver(() => this.resize()).observe(canvas.parentElement);
  }

  // parts: [{ hex, opacity, positions, triangles }]
  // mode: 'color' shows filament colors, 'mesh' shows the triangles in one plain color.
  // upsideDown turns the parts half a turn around the x axis and sets them back on the bed.
  show(parts, mode, upsideDown) {
    this.mode = mode;
    this.parts.children.forEach((child) => {
      child.geometry.dispose();
      child.material.dispose();
    });
    this.parts.clear();
    for (const part of parts) {
      const geometry = new THREE.BufferGeometry();
      geometry.setAttribute('position', new THREE.BufferAttribute(part.positions, 3));
      geometry.setIndex(new THREE.BufferAttribute(part.triangles, 1));
      this.parts.add(new THREE.Mesh(geometry, this.surfaceMaterial(part)), this.lines(geometry));
    }
    this.parts.rotation.x = upsideDown ? Math.PI : 0;
    this.parts.position.z = 0;
    this.parts.position.z = -new THREE.Box3().setFromObject(this.parts).min.z;
    this.render();
  }

  surfaceMaterial(part) {
    const shared = { flatShading: true, roughness: 0.75 };
    if (this.mode === 'mesh') return new THREE.MeshStandardMaterial({ ...shared, color: PLAIN_COLOR });
    const translucent = part.opacity < 1;
    // A translucent surface that writes depth hides the parts behind it.
    return new THREE.MeshStandardMaterial({ ...shared, color: part.hex, opacity: part.opacity, transparent: translucent, depthWrite: !translucent });
  }

  lines(geometry) {
    if (this.mode === 'mesh') {
      return new THREE.LineSegments(new THREE.WireframeGeometry(geometry), new THREE.LineBasicMaterial({ color: 0x000000, transparent: true, opacity: 0.45 }));
    }
    return new THREE.LineSegments(new THREE.EdgesGeometry(geometry, 30), new THREE.LineBasicMaterial({ color: 0x000000, transparent: true, opacity: 0.25 }));
  }

  fitCamera() {
    const sphere = new THREE.Box3().setFromObject(this.parts).getBoundingSphere(new THREE.Sphere());
    const direction = new THREE.Vector3(1, -1.3, 0.9).normalize();
    this.controls.target.copy(sphere.center);
    this.camera.position.copy(sphere.center).addScaledVector(direction, sphere.radius * 4);
    this.controls.update();
    this.render();
  }

  bed() {
    const grid = new THREE.GridHelper(BED_SIZE, BED_SIZE / GRID_STEP, 0x888888, 0x888888);
    grid.rotation.x = Math.PI / 2;
    grid.material.transparent = true;
    grid.material.opacity = 0.35;
    return grid;
  }

  lights() {
    const key = new THREE.DirectionalLight(0xffffff, 2.2);
    key.position.set(120, -160, 240);
    const fill = new THREE.DirectionalLight(0xffffff, 0.8);
    fill.position.set(-160, 120, 80);
    return [new THREE.HemisphereLight(0xffffff, 0x777777, 1.4), key, fill];
  }

  resize() {
    const { clientWidth, clientHeight } = this.renderer.domElement.parentElement;
    this.renderer.setSize(clientWidth, clientHeight);
    this.camera.aspect = clientWidth / clientHeight;
    this.camera.updateProjectionMatrix();
    this.render();
  }

  render() {
    this.renderer.render(this.scene, this.camera);
  }
}
