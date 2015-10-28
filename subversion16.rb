class Subversion16 < Formula
  desc "Version control system designed to be a better CVS"
  homepage "https://subversion.apache.org/"
  url "https://archive.apache.org/dist/subversion/subversion-1.6.16.tar.bz2"
  sha256 "214abc6b9359ea3a5fda2dee87dad110d1b33dcf888c1f8e361d69fbfa053943"

  bottle do
    revision 2
    sha256 "412d63fe92b65f47387d82019d6fc3182f38785726495cae185f6d2deea0cc20" => :yosemite
    sha256 "b13dd2a4574d01ef4afe26b66bb975b93249376446100f52f6f29a52376914f3" => :mavericks
    sha256 "c66db0cc2f6ee86adb9cef45ab31fff5dbb5a4416af6b83d7bd76e5ef2cc770c" => :mountain_lion
  end

  option :universal
  option "with-java", "Build Java bindings"
  option "with-perl", "Build Perl bindings"
  option "with-python", "Build Python bindings"
  option "with-ruby", "Build Ruby bindings"
  option "with-unicode-path", "Include support for OS X unicode (see caveats)"

  deprecated_option "java" => "with-java"
  deprecated_option "perl" => "with-perl"
  deprecated_option "python" => "with-python"
  deprecated_option "ruby" => "with-ruby"
  deprecated_option "unicode-path" => "with-unicode-path"

  depends_on "pkg-config" => :build

  # Requires system OpenSSL headers to build. >El Capitan no longer ship them.
  depends_on MaximumMacOSRequirement => :yosemite

  # On Snow Leopard, build a new neon. For Leopard, the deps below include this.
  # We don't use our OpenSSL because Neon refuses to support it due to wanting SSLv2
  # and using a more recent Neon via disabling the version check results in segfauls at runtime.
  if MacOS.version >= :snow_leopard
    depends_on :apr => :build
    depends_on :python => :optional
    depends_on "scons" => :build
    depends_on :java => :optional
  end

  # Homebrew's Swig is too new, Subversion throws a tantrum.
  resource "swig" do
    url "https://downloads.sourceforge.net/swig/swig-1.3.36.tar.gz"
    sha256 "47439796e3332dd6f5f9e2a45a26c5dc2a6bc93461c2e009d7cb493d1816dc1f"
  end

  # On 10.5 we need newer versions of apr, neon etc.
  # From get-deps.sh: "APR=apr-1.4.4"
  resource "apr" do
    url "https://archive.apache.org/dist/apr/apr-1.4.4.tar.bz2"
    sha256 "15372afeb6bba4091c4662600dad8bc51e5e4ff15ce308fac286df8735eb544d"
  end

  # APR_UTIL=apr-util-1.3.11
  resource "apr-util" do
    url "https://archive.apache.org/dist/apr/apr-util-1.3.11.tar.bz2"
    sha256 "13b8446c5ff96ed32293db77689992db18addb1a76d0f6dae29f132dc96dab59"
  end

  # SERF=serf-0.7.0
  resource "serf" do
    url "http://serf.googlecode.com/svn/trunk/", :tag => "0.7.0"
  end

  # ZLIB=zlib-1.2.8
  resource "zlib" do
    url "http://zlib.net/zlib-1.2.8.tar.gz"
    sha256 "36658cb768a54c1d4dec43c3116c27ed893e88b02ecfcb44f2166f9c0b7f2a0d"
  end

  resource "sqlite-amalgamation" do
    url "http://www.sqlite.org/sqlite-amalgamation-3070500.zip"
    sha256 "ce0f8855c8fb08e1b65fa864b9ac33650b3afd373a72da2a6ff7f813b178240a"
  end

  resource "neon" do
    url "http://webdav.org/neon/neon-0.28.3.tar.gz"
    sha256 "90dee51b4c70bc50ce2fa106ca945349b81cd86c90aa9d4dbff73abb284fcdc2"
  end

  # Patch to find Java headers
  patch :p0 do
    url "https://trac.macports.org/export/73004/trunk/dports/devel/subversion-javahlbindings/files/patch-configure.diff"
    sha256 "2524f14483a2db859c0ae9da1edec49b5450d3ae0393b36f7a329ed66f596493"
  end

  # Patch for subversion handling of OS X Unicode paths (see caveats)
  if build.with? "unicode-path"
    patch do
      url "https://gist.githubusercontent.com/simonc/434424/raw/0d22bfa9be3e7f924c97de521c24c66b99a8cf0a/subversion-unicode-path.patch"
      sha256 "944e8202dc50bee4212e96d4c3d42cdfbefdf62765a24563938f48510de065fe"
    end
  end

  def setup_leopard
    # Slot dependencies into place
    (buildpath).install resource("apr")
    (buildpath).install resource("apr-util")
    (buildpath).install resource("serf")
    (buildpath).install resource("zlib")
    (buildpath).install resource("sqlite-amalgamation")
    (buildpath).install resource("neon")
  end

  def install
    ENV.universal_binary if build.universal?

    if MacOS.version == :leopard
      setup_leopard
    else
      # Homebrew's Neon is too new and causes segfaults on all OS X versions now.
      resource("neon").stage do
        system "./configure", "--prefix=#{libexec}/neon", "--enable-shared",
                              "--disable-static", "--disable-nls", "--with-ssl=openssl",
                              "--with-libs=/usr/lib"
        system "make", "install"
      end

      ENV.prepend_path "PATH", libexec/"neon/bin"
      ENV.prepend "CFLAGS", "-I#{libexec}/neon/include"
      ENV.prepend "LDFLAGS", "-L#{libexec}/neon/lib"
      ENV.prepend_path "PKG_CONFIG_PATH", libexec/"neon/lib/pkgconfig"
    end

    if build.with?("perl") || build.with?("python") || build.with?("ruby") && MacOS.version >= :snow_leopard
      resource("swig").stage do
        system "./configure", "--prefix=#{buildpath}/swig", "--disable-debug", "--disable-dependency-tracking"
        system "make"
        system "make", "install"
      end
      ENV.prepend_path "PATH", buildpath/"swig/bin"
    end

    if build.with? "java"
      unless build.universal?
        opoo "A non-Universal Java build was requested."
        puts "To use Java bindings with various Java IDEs, you might need a universal build:"
        puts "brew install subversion --universal --java"
      end
    end

    # Use existing system zlib
    # Use dep-provided other libraries
    # Don't mess with Apache modules (since we're not sudo)
    args = ["--disable-debug",
            "--prefix=#{prefix}",
            "--with-ssl",
            "--with-zlib=/usr",
            "--with-sqlite=#{MacOS.sdk_path}/usr",
            # use our neon, not OS X's
            "--disable-neon-version-check",
            "--disable-mod-activation",
            "--without-apache-libexecdir",
            # Don't try to use httpd, because the one included
            # with more recent versions of OS X is incompatible.
            "--without-apxs",
            "--without-berkeley-db"]

    if MacOS::CLT.installed?
      args << "--with-apr=/usr"
      args << "--with-apr-util=/usr"
    else
      args << "--with-apr=#{Formula["apr"].opt_prefix}"
      args << "--with-apr-util=#{Formula["apr-util"].opt_prefix}"
    end

    args << "--enable-javahl" << "--without-jikes" if build.with? "java"
    args << "RUBY=/usr/bin/ruby" << "--with-ruby-sitedir=#{lib}/ruby" if build.with? "ruby"
    args << "--with-unicode-path" if build.with? "unicode_path"

    # Undo a bit of the MacPorts patch
    inreplace "configure", "@@DESTROOT@@/", ""

    system "./configure", *args
    system "make"
    system "make", "install"

    if build.with? "python"
      system "make", "swig-py"
      system "make", "install-swig-py"
    end

    # Newer OS X Perl's are too incompatible with svn16.
    # swigutil_pl.c:23:10: fatal error: 'EXTERN.h' file not found
    if build.with?("perl") && MacOS.version < :lion
      ENV.deparallelize # This build isn't parallel safe
      # Remove hard-coded ppc target, add appropriate ones
      if build.universal?
        arches = Hardware::CPU.universal_archs.as_arch_flags
      elsif MacOS.version == :leopard
        arches = "-arch #{Hardware::CPU.arch_32_bit}"
      else
        arches = "-arch #{Hardware::CPU.arch_64_bit}"
      end

      # Use version-appropriate system Perl
      if MacOS.version == :leopard
        perl_version = "5.8.8"
      else
        perl_version = "5.10.0"
      end

      inreplace "Makefile" do |s|
        s.change_make_var! "SWIG_PL_INCLUDES",
          "$(SWIG_INCLUDES) #{arches} -g -pipe -fno-common -DPERL_DARWIN -fno-strict-aliasing -I/usr/local/include -I/System/Library/Perl/#{perl_version}/darwin-thread-multi-2level/CORE"
      end
      system "make", "swig-pl"
      system "make", "install-swig-pl"
    end

    if build.with? "java"
      ENV.deparallelize # This build isn't parallel safe
      system "make", "javahl"
      system "make", "install-javahl"
    end

    if build.with? "ruby"
      ENV.deparallelize # This build isn't parallel safe
      system "make", "swig-rb"
      system "make", "install-swig-rb"
    end
  end

  def caveats
    s = ""

    if build.with? "unicode_path"
      s += <<-EOS.undent
        This unicode-path version implements a hack to deal with composed/decomposed
        unicode handling on Mac OS X which is different from linux and windows.
        It is an implementation of solution 1 from
        http://svn.collab.net/repos/svn/trunk/notes/unicode-composition-for-filenames
        which _WILL_ break some setups. Please be sure you understand what you
        are asking for when you install this version.

      EOS
    end

    if build.with? "python"
      s += <<-EOS.undent
        You may need to add the Python bindings to your PYTHONPATH from:
          #{HOMEBREW_PREFIX}/lib/svn-python

      EOS
    end

    if build.with? "ruby"
      s += <<-EOS.undent
        You may need to add the Ruby bindings to your RUBYLIB from:
          #{HOMEBREW_PREFIX}/lib/ruby

      EOS
    end

    if build.with? "java"
      s += <<-EOS.undent
        You may need to link the Java bindings into the Java Extensions folder:
          sudo mkdir -p /Library/Java/Extensions
          sudo ln -s #{HOMEBREW_PREFIX}/lib/libsvnjavahl-1.dylib /Library/Java/Extensions/libsvnjavahl-1.dylib

      EOS
    end

    s
  end

  test do
    system bin/"svn", "--version"
  end
end
