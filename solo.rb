cookbook_path File.expand_path("../cookbooks", __FILE__)
log_level :info

# File cache path - where Chef stores temporary data
file_cache_path File.expand_path("../cache", __FILE__)

# Node name for this run
node_name "xcp-ng-vm"
