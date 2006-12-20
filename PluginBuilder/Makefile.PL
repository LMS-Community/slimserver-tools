use inc::Module::Install;

# Define metadata
name            ('Slim-PluginBuilder');
#all_from        ('lib/Slim/PluginBuilder.pm');
license		('perl');
version		('1.0');

# Specific dependencies
requires        ('Archive::Zip'      => 0);
requires        ('Data::UUID'        => 0);
requires        ('Getopt::Long'      => 0);
requires        ('PAR'               => 0);
requires        ('PAR::Dist'         => 0);
requires        ('PAR::Packer'       => 0);
requires        ('Module::CoreList'  => 0);
requires        ('XML::Simple'       => 0);

install_script  ('bin/create-slimserver-plugin');

auto_install();
WriteAll();
