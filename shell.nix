{ pkgs ? import <nixpkgs> {} }:
let
    python3 = pkgs.python3.withPackages(
        ps: with ps; [pymavlink]
    );
    pymavlink = python3.pkgs.pymavlink;
    generator = pkgs.writeShellScriptBin "generate-mavlink.sh"
    ''
        ${pymavlink}/bin/mavgen.py \
            --lang=$1 \
            --wire-protocol=2.0 \
            --output $2/include/mavlink \
            ./message_definitions/v1.0/$3.xml
    '';

    generate-cc11-headers-and-tar = pkgs.writeShellScriptBin "generate-cc11-headers-and-tar"
    ''
        TAGS=$(${pkgs.git}/bin/git tag --points-at HEAD | xargs)
        DIRTY=$(${pkgs.git}/bin/git diff --quiet && git diff --cached --quiet || echo "-dirty")
        REV=$(${pkgs.git}/bin/git rev-parse HEAD)$DIRTY
        BRANCH=$(${pkgs.git}/bin/git branch --show-current)
        REMOTE=$(${pkgs.git}/bin/git config --get remote.origin.url)
        TMPDIR=$(mktemp -d)
        INSTALL_DIR=$TMPDIR/mavlink-$REV/mavlink
        DIR=$(pwd)
        ${generator}/bin/generate-mavlink.sh C++11 $INSTALL_DIR "scoutco"
        pushd $TMPDIR
        SRCINFO=mavlink-$REV/source_info.txt
        echo "REV=$REV" >        $SRCINFO
        echo "BRANCH=$BRANCH" >> $SRCINFO
        echo "REMOTE=$REMOTE" >> $SRCINFO
        echo "TAGS=$TAGS"     >> $SRCINFO
        ${pkgs.gnutar}/bin/tar -czf $DIR/mavlink-$REV.tar.gz mavlink-$REV
        popd
    '';
in
pkgs.mkShell {
  buildInputs = [
    pkgs.stdenv.cc   # provides gcc/clang + libc
    pkgs.cmake       # build system
    #python3
    python3.pkgs.pymavlink
    generator
    generate-cc11-headers-and-tar
  ];
}
