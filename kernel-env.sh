export CROSS_COMPILE="ccache powerpc-unknown-linux-gnu-"
export CC="ccache powerpc-unknown-linux-gnu-gcc"
export ARCH=powerpc

datefmt() {
        date '+%-m-%d-%Y__%H:%M:%S'
}

accept_incoming() {
	git checkout HEAD -- $1
	git add $1
}
