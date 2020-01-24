{ stdenv
, buildPythonApplication
, lib
, python
, fetchurl
, fetchFromGitHub
, lame
, mplayer
, libpulseaudio
, pyqtwebengine
, decorator
, beautifulsoup4
, sqlalchemy
, pyaudio
, requests
, markdown
, matplotlib
, pytest
, glibcLocales
, nose
, jsonschema
, setuptools
, send2trash
, CoreAudio
# This little flag adds a huge number of dependencies, but we assume that
# everyone wants Anki to draw plots with statistics by default.
, plotsSupport ? true
# manual
, asciidoc
}:

let
    version = "2.1.19";

    # when updating, also update rev-manual to a recent version of
    # https://github.com/dae/ankidocs
    # The manual is distributed independently of the software.
    manual = stdenv.mkDerivation {
      pname = "anki-manual";
      inherit version;
      src = fetchFromGitHub {
        owner = "ankitects";
        repo = "anki-docs";
        rev = "d0d993d54932348b74b8e39cdca540195d99c56d";
        sha256 = "15z2ibrgib5mjgb85gxizs88dmjbnpzs9gdg6z3sx64xi7ckzq6y";
      };
      phases = [ "unpackPhase" "patchPhase" "buildPhase" ];
      nativeBuildInputs = [ asciidoc ];
      patchPhase = ''
        # rsync isnt needed
        # WEB is the PREFIX
        # We remove any special ankiweb output generation
        # and rename every .mako to .html
        sed -e 's/rsync -a/cp -a/g' \
            -e "s|\$(WEB)/docs|$out/share/doc/anki/html|" \
            -e '/echo asciidoc/,/mv $@.tmp $@/c \\tasciidoc -b html5 -o $@ $<' \
            -e 's/\.mako/.html/g' \
            -i Makefile
        # patch absolute links to the other language manuals
        sed -e 's|https://apps.ankiweb.net/docs/|link:./|g' \
            -i {manual.txt,manual.*.txt}
        # there’s an artifact in most input files
        sed -e '/<%def.*title.*/d' \
            -i *.txt
        mkdir -p $out/share/doc/anki/html
      '';
    };

in
buildPythonApplication rec {
    pname = "anki";
    inherit version;

    src = fetchFromGitHub {
      owner = "ankitects";
      repo = pname;
      rev = version;
      sha256 = "0lcm13dcjg8xl5id47vi7h6np3vgh5wrn2w0cqfw6as2ff28bn0j";
    };

    outputs = [ "out" "doc" "man" ];

    propagatedBuildInputs = [
      pyqtwebengine sqlalchemy beautifulsoup4 send2trash pyaudio requests decorator
      markdown jsonschema setuptools
    ]
      ++ lib.optional plotsSupport matplotlib
      ++ lib.optional stdenv.isDarwin [ CoreAudio ]
      ;

    checkInputs = [ pytest glibcLocales nose ];

    nativeBuildInputs = [ pyqtwebengine.wrapQtAppsHook ];
    buildInputs = [ lame mplayer libpulseaudio  ];

    patches = [
      # Disable updated version check.
      ./no-version-check.patch
    ];

    buildPhase = ''
      # Dummy build phase
      # Anki does not use setup.py
    '';

    postPatch = ''
      # Remove unused starter. We'll create our own, minimalistic,
      # starter.
      # rm anki/anki

      # Remove QT translation files. We'll use the standard QT ones.
      rm "locale/"*.qm

      # hitting F1 should open the local manual
      substituteInPlace pylib/anki/consts.py \
        --replace 'HELP_SITE = "http://ankisrs.net/docs/manual.html"' \
                  'HELP_SITE = "${manual}/share/doc/anki/html/manual.html"'
    '';

    # UTF-8 locale needed for testing
    LC_ALL = "en_US.UTF-8";

    checkPhase = ''
      # - Anki writes some files to $HOME during tests
      # - Skip tests using network
      env HOME=$TMP pytest --ignore tests/test_sync.py
    '';

    installPhase = ''
      pp=$out/lib/${python.libPrefix}/site-packages

      mkdir -p $out/bin
      mkdir -p $out/share/applications
      mkdir -p $doc/share/doc/anki
      mkdir -p $man/share/man/man1
      mkdir -p $out/share/mime/packages
      mkdir -p $out/share/pixmaps
      mkdir -p $pp

      cat > $out/bin/anki <<EOF
      #!${python}/bin/python
      import aqt
      aqt.run()
      EOF
      chmod 755 $out/bin/anki

      cp -v qt/anki.desktop $out/share/applications/
      cp -v README* LICENSE* $doc/share/doc/anki/
      cp -v qt/anki.1 $man/share/man/man1/
      cp -v qt/anki.xml $out/share/mime/packages/
      cp -v qt/anki.{png,xpm} $out/share/pixmaps/
      cp -rv locale $out/share/
      cp -rv anki aqt web $pp/

      # copy the manual into $doc
      cp -r ${manual}/share/doc/anki/html $doc/share/doc/anki
    '';

    dontWrapQtApps = true;

    preFixup = ''
      makeWrapperArgs+=(
        "''${qtWrapperArgs[@]}"
        --prefix PATH ':' "${lame}/bin:${mplayer}/bin"
      )
    '';

    # now wrapPythonPrograms from postFixup will add both python and qt env variables

    passthru = {
      inherit manual;
    };

    meta = with lib; {
      homepage = "https://apps.ankiweb.net/";
      description = "Spaced repetition flashcard program";
      longDescription = ''
        Anki is a program which makes remembering things easy. Because it is a lot
        more efficient than traditional study methods, you can either greatly
        decrease your time spent studying, or greatly increase the amount you learn.

        Anyone who needs to remember things in their daily life can benefit from
        Anki. Since it is content-agnostic and supports images, audio, videos and
        scientific markup (via LaTeX), the possibilities are endless. For example:
        learning a language, studying for medical and law exams, memorizing
        people's names and faces, brushing up on geography, mastering long poems,
        or even practicing guitar chords!
      '';
      license = licenses.agpl3Plus;
      broken = stdenv.hostPlatform.isAarch64;
      platforms = platforms.mesaPlatforms;
      maintainers = with maintainers; [ oxij the-kenny Profpatsch enzime ];
    };
}
