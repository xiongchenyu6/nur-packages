{
  kwalify = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1ngxg3ysq5vip9dn3d32ajc7ly61kdin86hfycm1hkrcvkkn1vjf";
      type = "gem";
    };
    version = "0.7.2";
  };
  net-ldap = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0xqcffn3c1564c4fizp10dzw2v5g2pabdzrcn25hq05bqhsckbar";
      type = "gem";
    };
    version = "0.18.0";
  };
  pg = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1zcvxmfa8hxkhpp59fhxyxy1arp70f11zi1jh9c7bsdfspifb7kb";
      type = "gem";
    };
    version = "1.5.3";
  };
  pg-ldap-sync = {
    dependencies = ["kwalify" "net-ldap" "pg"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1x3mw9jbm1j7yvmbj5y8gj9lx218a717qs54jbgh1l68ifg045b2";
      type = "gem";
    };
    version = "0.4.0";
  };
}
