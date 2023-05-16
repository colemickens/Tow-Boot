{
  device = {
    manufacturer = "StarFive";
    name = "VisionFive";
    identifier = "starFive-visionFive";
    productPageURL = "https://starfivetech.com/en/site/exploit/";
  };

  # TODO: what's the point of hardware options for this
  # if the presented API winds up just being stringy
  # anyway???
  hardware = {
    soc = "starfive-jh7110";
  };

  Tow-Boot = {
    defconfig = "starfive_visionfive2_defconfig";
    src = {
    };
  };
}
