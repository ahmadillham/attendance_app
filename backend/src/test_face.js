const { initFaceApi, extractDescriptor } = require('./lib/faceDescriptor');

async function main() {
  await initFaceApi();
  // Using dummy.jpg which is already in backend directory
  const desc = await extractDescriptor('../dummy.jpg');
  console.log(desc ? `Descriptor extracted: ${desc.length} length` : 'No descriptor');
}
main().catch(console.error);
