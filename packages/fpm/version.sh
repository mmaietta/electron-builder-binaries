# extract ruby version but without the patch version
export RUBY_VERSION="$(ruby -e 'print RUBY_VERSION' | grep -oE '([0-9]+\.){1}[0-9]+' | head -n 1).0"
export FPM_VERSION=1.16.0