const MAXTILESIZE = @isdefined(MAXTILESIZE) ? MAXTILESIZE : 10
const FUZZ_SEED = @isdefined(FUZZ_SEED) ? FUZZ_SEED : rand(UInt)
@info "MAXTILESIZE: $MAXTILESIZE"
@info "FUZZ_SEED: $FUZZ_SEED"
Random.seed!(FUZZ_SEED)
