import ./make-test-python.nix ({ pkgs, ... }: {
  name = "swbs-test";

  general = {
    data_period = 1;
  };
})
