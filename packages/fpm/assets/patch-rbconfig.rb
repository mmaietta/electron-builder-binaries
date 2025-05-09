#!/usr/bin/env ruby
# patch_rbconfig.rb
# Patches hardcoded paths in rbconfig.rb to match the current bundle location (Ruby 3.4.0 compatible)

require 'rbconfig'
require 'fileutils'

# Define the new prefix root (directory where this script lives)
BUNDLE_ROOT = File.expand_path(File.dirname(__FILE__))

# Find rbconfig.rb from $LOAD_PATH
rbconfig_path = $LOAD_PATH.map { |p| File.join(p, 'rbconfig.rb') }
                          .find { |f| File.exist?(f) }

# abort("❌ Could not find rbconfig.rb in LOAD_PATH") unless rbconfig_path

# puts "🛠 Found rbconfig.rb at: #{rbconfig_path}"

# Create a backup if not already saved
backup_path = "#{rbconfig_path}.bak"
if File.exist?(backup_path)
#   puts "⏭️ Already patched rbconfig.rb to use #{BUNDLE_ROOT}"
  exit 0
else
  FileUtils.cp(rbconfig_path, backup_path)
#   puts "🧯 Backed up original to: #{backup_path}"
end

# puts "📦 New bundle root: #{BUNDLE_ROOT}"

# Read the original content
original = File.read(rbconfig_path)
patched = original.dup

# Patch CONFIG and MAKEFILE_CONFIG entries
# def patch_hash(content, hash_name, key, old_path, new_path)
#   old_escaped = Regexp.escape(old_path)
#   new_escaped = new_path.gsub("\\", "\\\\\\\\")
#   content.gsub!(
#     /(#{hash_name}\[\s*['"]#{Regexp.escape(key)}['"]\s*\]\s*=\s*)['"]#{old_escaped}['"]/,
#     "\\1\"#{new_escaped}\""
#   )
# end

# RbConfig::CONFIG.each do |key, val|
#   next unless val.start_with?('/')
#   new_val = File.join(BUNDLE_ROOT, val.sub(%r{^/}, ''))
#   patch_hash(patched, "CONFIG", key, val, new_val)
# end

# RbConfig::MAKEFILE_CONFIG.each do |key, val|
#   next unless val.start_with?('/')
#   new_val = File.join(BUNDLE_ROOT, val.sub(%r{^/}, ''))
#   patch_hash(patched, "MAKEFILE_CONFIG", key, val, new_val)
# end

# Patch TOPDIR to use bundle root
# This is a workaround for Ruby 3.4.0 where TOPDIR is hardcoded in rbconfig.rb and not set in CONFIG or MAKEFILE_CONFIG
patched.gsub!(
  /TOPDIR = .*$/,
  "TOPDIR = \"#{BUNDLE_ROOT}\""
)

# Write patched rbconfig.rb
File.write(rbconfig_path, patched)
# puts "✅ Patched rbconfig.rb to use bundle root: #{BUNDLE_ROOT}"
