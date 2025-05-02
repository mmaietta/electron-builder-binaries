export RUBY_VERSION=$(ruby --version | grep -oE '([0-9]+\.){2}[0-9]+' | head -n 1)
export FPM_VERSION=1.16.0