{
  package, wrapShellScriptBin, coreutils, gnutar,
  gzip ? null, bzip2 ? null, lz4 ? null, xz ? null, gnupg ? null, fucky ? null
}:
package (wrapShellScriptBin "benc" ./benc.sh) {
  depsRuntimePath = [coreutils gnutar gnupg gzip bzip2 lz4 xz fucky];
}
