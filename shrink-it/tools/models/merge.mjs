import { NodeIO } from '@gltf-transform/core';
import { mergeDocuments, textureCompress, dedup, prune, unpartition } from '@gltf-transform/functions';
import sharp from 'sharp';
const io = new NodeIO();
const parts = [
  ['BearTrap', 'beartrap.glb'],
  ['MobileShop', './mobile_shop.glb'],
  ['Flowers', './flowers_pack_1.glb'],
  ['Cars', './low_poly_cars.glb'],
  ['Cars2', './ultimate_low-poly_car_pack_2.glb'],
  ['Cars3', './4_low_poly_toon_city_cars.glb'],
];
const doc = await io.read(parts[0][1]);
const root = doc.getRoot();
const scene = root.getDefaultScene() || root.listScenes()[0];
function wrap(sc, name) {
  const w = doc.createNode(name);
  for (const n of sc.listChildren()) { sc.removeChild(n); w.addChild(n); }
  return w;
}
const wrappers = [wrap(scene, parts[0][0])];
for (const [name, file] of parts.slice(1)) {
  const before = new Set(root.listScenes());
  const src = await io.read(file);
  mergeDocuments(doc, src);
  for (const sc of root.listScenes()) if (!before.has(sc)) { wrappers.push(wrap(sc, name)); sc.dispose(); }
}
for (const w of wrappers) scene.addChild(w);
for (const a of root.listAnimations()) a.dispose();
for (const m of root.listMaterials()) if (m.getAlphaMode() === 'BLEND' && wrappers[0]) m.setAlphaMode('OPAQUE');
root.setDefaultScene(scene);
await doc.transform(unpartition(), dedup(), prune(), textureCompress({ encoder: sharp, resize: [1024, 1024] }));
await io.write('ShrinkIt_Models.glb', doc);
console.log('scenes', root.listScenes().length, 'top nodes', scene.listChildren().map(n => n.getName()).join(','));
