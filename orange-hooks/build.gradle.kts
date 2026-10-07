// Tiny, dependency-free runtime API. The agent puts this jar on the *bootstrap* class path,
// so bytecode patched into Minecraft classes can call it no matter which class loader the
// server uses (Paperclip, the vanilla bundler, Fabric's Knot, ...).
