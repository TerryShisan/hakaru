{-# LANGUAGE NoImplicitPrelude
           , DataKinds
           , TypeFamilies
           , FlexibleContexts
           #-}
{-# OPTIONS_GHC -Wall -fwarn-tabs #-}
module Tests.Relationships (allTests) where

import Prelude ((.), id, ($), asTypeOf)

import Language.Hakaru.Syntax.Prelude
import Language.Hakaru.Types.DataKind
import Language.Hakaru.Syntax.AST (Term)
import Language.Hakaru.Syntax.ABT (ABT)

import Test.HUnit
import Tests.TestTools
import Tests.Models (normal_0_1, uniform_0_1)


allTests :: Test
allTests = test
    [ testRelationships
    ]

testRelationships :: Test
testRelationships = test [
    "t1"   ~: testSS [t1] (lam $ \_ -> lam $ \_ -> normal_0_1),
    "t2"   ~: testSS [t2] (lam $ \b -> gamma b 2),
    "t3"   ~: testSS [t3, t3'] (lam $ \a -> lam $ \x -> gamma a 2),
    "t4"   ~: testSS [t4] (lam $ \a -> lam $ \b -> lam $ \_ -> beta a b),
    "t5"   ~: testSS [t5, t5'] (lam $ \alpha -> gamma one alpha),
    --"t6"   ~: testSS [t5] (lam $ \mu -> poisson mu >>= \x -> dirac (fromInt x)),
    "t7"   ~: testSS [t7]
        (normal_0_1 >>= \x1 ->
        normal_0_1 >>= \x2 ->
        dirac (x1 * recip x2)),

    "t8"   ~: testSS [t8]
        (lam $ \a ->
        lam $ \alpha ->
        (normal_0_1 >>= \x1 ->
        normal_0_1 >>= \x2 ->
        dirac (a + fromProb alpha * (x1 / x2)))),

    "t9"   ~: testSS [t9]
        (lam $ \p -> bern p >>= \x -> dirac (if_ x one zero)),
    --Doesn't (if_ x one zero) simplify to just x?--Carl 2016Jul16
     

    "t10"  ~: testSS [t10] (unsafeProb <$> uniform_0_1),

    "t11"  ~: testSS [t11]
        (lam $ \a1 ->
        lam $ \a2 ->
        gamma one (unsafeProb a1) >>= \x1 ->
        gamma one a2 >>= \x2 ->
        dirac (fromProb (x1 - x2))),

    -- sum of n exponential(b) random variables is a gamma(n, b) random variable
    "t12"   ~: testSS [t12] (lam $ \b -> gamma 2 b),

    --  Weibull(b, 1) random variable is an exponential random variable with mean b
    --Above comment is wrong. Should be:
    --X ~ Weibull(a,1)  =>  X ~ Exponential(1/a) 
    --"t13"   ~: testSS [t13] (lam $ \b -> exponential (recip b)),
    --Above line is wrong. Should be:
    "t13"   ~: testSS [t13] (lam $ \a -> exponential(recip a)),
    --Carl 2016Jul14

    -- If X is a standard normal random variable and U is a chi-squared random variable with v degrees of freedom,
    -- then X/sqrt(U/v) is a Student's t(v) random variable
    "t14"   ~: testSS [t14] (lam $ \v -> studentT zero one v),

    "t15"   ~: testSS [t15] (lam $ \k -> lam $ \t -> gamma k t),

    -- Linear combination property
    "t16"   ~: testSS [t16] (normal zero (sqrt 2)),
    "t17"   ~: testSS [t17]
        (lam $ \mu ->
        lam $ \sigma ->
        normal mu (sqrt (one + sigma * sigma))),
    "t18"   ~: testSS [t18]
        (lam $ \a1 ->
        lam $ \a2 ->
        normal zero (sqrt (a1 * a1 + a2 * a2))),

    -- Convolution property
    "t19"   ~: testSS [t19]
        (lam $ \n1 ->
        lam $ \n2 ->
        lam $ \p ->
        binomial (n1 + n2) p),
    "t20"   ~: testSS [t20]
        (lam $ \n ->
        lam $ \p ->
        binomial n p),
    "t21"   ~: testSS [t21]
        (lam $ \l1 ->
        lam $ \l2 ->
        poisson (l1 + l2)),
    "t22"   ~: testSS [t22]
        (lam $ \a1 ->
        lam $ \a2 ->
        lam $ \b ->
        gamma (a1 + a2) b),
    "t23"   ~: testSS [t23] (lam $ \n -> lam $ \t -> gamma n t),

--I can't find any evidence for the truth of relationship t24. Indeed,
--it's trivial to prove false.--Carl 2016Jul16
--    -- Scaling property
--    "t24"   ~: testSS [t24]
--        (lam $ \a ->
--        lam $ \b ->
--        lam $ \k ->
--        weibull (a * (k ** fromProb b)) b),

--The next test is wrong. The log x should be exp x (or whatever the
--exponential function is in Haskell).
    -- Product property
    "t25"   ~: testSS [t25]
        (lam $ \mu1 ->
        lam $ \mu2 ->
        lam $ \sigma1 ->
        lam $ \sigma2 ->
        normal (mu1 + mu2) (sigma1 + sigma2) >>= \x ->
        dirac (log x)),

    -- Inverse property
--I can't verify the relationship below. It's easy to prove false, except for
--the case l=0, where it's true. Where did it come from? It's too complex to
--have been entered by mistake.--Carl 2016Jul17 
    "t26"   ~: testSS [t26]
        (lam $ \l ->
        lam $ \s ->
        cauchy (l / (l*l + fromProb (s*s)))
            (s / (unsafeProb (l*l) + s*s))),

    -- Multiple of a random variable
    "t27"   ~: testSS [t27]
        (lam $ \r ->
        lam $ \lambda ->
        lam $ \a ->
        gamma r (a * lambda)),

    -- If X is a beta (a, b) random variable then (1 - X) is a beta (b, a) random variable.
    "t28"   ~: testSS [t28] (lam $ \a -> lam $ \b -> beta b a))),

    -- If X is a binomial (n, p) random variable then (n - X) is a binomial (n, 1-p) random variable.
    "t29"   ~: testSS [t29] (lam $ \n -> lam $ \p -> binomial n (one - p))))
    ]

t1  :: (ABT Term abt) => abt '[] ('HReal ':-> 'HProb ':-> 'HMeasure 'HReal)
t1 = lam (\mu -> (lam (\sigma ->
    normal mu sigma >>= \x ->
    dirac ((x - mu) / (fromProb sigma)))))

t2  :: (ABT Term abt) => abt '[] ('HProb ':-> 'HMeasure 'HProb)
t2 = lam $ \b -> chi2 (2 * b)

-- This test (and probably many others involving gamma) is wrong,
-- because the argument order to our gamma is the opposite of
-- the order used by 2008amstat.pdf
t3  :: (ABT Term abt) => abt '[] ('HProb ':-> 'HProb ':-> 'HMeasure 'HProb)
t3 =
    lam $ \alpha ->
    lam $ \bet ->
    gamma alpha bet >>= \x ->
    dirac (2 * x / bet)

t3' :: (ABT Term abt) => abt '[] ('HProb ':-> 'HProb ':-> 'HMeasure 'HProb)
t3' = lam $ \_ -> lam $ \bet -> chi2 (2 * bet)

t4  :: (ABT Term abt)
    => abt '[] ('HProb ':-> 'HProb ':-> 'HProb ':-> 'HMeasure 'HProb)
t4 =
    lam $ \a ->
    lam $ \b ->
    lam $ \t -> 
    gamma a t >>= \x1 ->
    gamma b t >>= \x2 ->
    dirac (x1 / (x1+x2))

t5 :: (ABT Term abt) => abt '[] ('HProb ':-> 'HMeasure 'HProb)
t5 =
    lam $ \alpha ->
    uniform_0_1 >>= \x ->
    dirac (negate alpha * unsafeProb (log (unsafeProb x)))

t5' :: (ABT Term abt) => abt '[] ('HProb ':-> 'HMeasure 'HProb)
t5' =
    lam $ \alpha ->
    laplace (fromProb alpha) alpha >>= \x ->
    dirac (abs (unsafeProb x))

-- Untestable right now with mu -> infinity, maybe later?
--t6 :: (ABT Term abt) => abt '[] ('HProb ':-> 'HMeasure 'HReal)
--t6 = lam (\mu -> normal infinity mu)

t7 :: (ABT Term abt) => abt '[] ('HMeasure 'HReal)
t7 = cauchy zero one

t8 :: (ABT Term abt) => abt '[] ('HReal ':-> 'HProb ':-> 'HMeasure 'HReal)
t8 = lam $ \a -> lam $ \alpha -> cauchy a alpha

t9 :: (ABT Term abt) => abt '[] ('HProb ':-> 'HMeasure 'HInt)
t9 = lam $ \p -> binomial one p

t10 :: (ABT Term abt) => abt '[] ('HMeasure 'HProb)
t10 = beta one one

t11 :: (ABT Term abt) => abt '[] ('HReal ':-> 'HProb ':-> 'HMeasure 'HReal)
t11 = lam $ \a1 -> lam $ \a2 -> laplace a1 a2

t12 :: (ABT Term abt) => abt '[] ('HProb ':-> 'HMeasure 'HProb)
t12 =
    lam $ \b ->
    exponential b >>= \x1 ->
    exponential b >>= \x2 ->
    dirac (x1 + x2)

t13 :: (ABT Term abt) => abt '[] ('HProb ':-> 'HMeasure 'HProb)
--t13 = lam $ \b -> weibull one b
--Parameter order wrong in line above.--Carl 2016Jul14
t13 = lam $ \a -> weibull a one

t14 :: (ABT Term abt) => abt '[] ('HProb ':-> 'HMeasure 'HReal)
t14 =
    lam $ \v ->
    normal_0_1 >>= \x ->
    chi2 v >>= \u ->
    dirac (x / fromProb (sqrt (u / v)))

t15 :: (ABT Term abt) => abt '[] ('HProb ':-> 'HProb ':-> 'HMeasure 'HProb)
t15 =
    lam $ \k ->
    lam $ \t ->
    invgamma k (recip t) >>= \x ->
    dirac (recip x)

t16 :: (ABT Term abt) => abt '[] ('HMeasure 'HReal)
t16 =
    normal_0_1 >>= \x1 ->
    normal_0_1 >>= \x2 ->
    dirac (x1 + x2)

t17 :: (ABT Term abt) => abt '[] ('HReal ':-> 'HProb ':-> 'HMeasure 'HReal)
t17 =
    lam $ \mu ->
    lam $ \sigma ->
    normal_0_1 >>= \x1 ->
    normal mu sigma >>= \x2 ->
    dirac (x1 + x2)

--I corrected the below. The relationship is about two rvs, not one. 
t18 :: (ABT Term abt) => abt '[] ('HProb ':-> 'HProb ':-> 'HMeasure 'HReal)
t18 =
    lam $ \a1 ->
    lam $\a2 ->
    normal_0_1 >>= \x ->
    normal_0_1 >>= \y
    --dirac (fromProb a1 * x + fromProb a2 * x)
    dirac (fromProb a1 * x + fromProb a2 * y)
--Actually, this relation is also true if a1 < 0 and/or a2 < 0. 

t19 :: (ABT Term abt)
    => abt '[] ('HInt ':-> 'HInt ':-> 'HProb ':-> 'HMeasure 'HInt)
t19 =
    lam $ \n1 ->
    lam $ \n2 ->
    lam $ \p ->
    binomial n1 p >>= \x1 ->
    binomial n2 p >>= \x2 ->
    dirac (x1 + x2)

--The next test is completely wrong. It's supposed to express something about
--the sum of n iid Bernoulli rvs. That's not the same thing as n times a single
--rv. Also, if_ x one zero simplifies to simply x.
t20 :: (ABT Term abt) => abt '[] ('HInt ':-> 'HProb ':-> 'HMeasure 'HInt)
t20 =
    lam $ \n ->
    lam $ \p ->
    bern p >>= \x ->
    dirac (n * if_ x one zero)

t21 :: (ABT Term abt) => abt '[] ('HProb ':-> 'HProb ':-> 'HMeasure 'HInt)
t21 =
    lam $ \l1 ->
    lam $ \l2 ->
    poisson l1 >>= \x1 ->
    poisson l2 >>= \x2 ->
    dirac (x1 + x2)

t22 :: (ABT Term abt)
    => abt '[] ('HProb ':-> 'HProb ':-> 'HProb ':-> 'HMeasure 'HProb)
t22 =
    lam $ \a1 ->
    lam $ \a2 ->
    lam $ \b ->
    gamma a1 b >>= \x1 ->
    gamma a2 b >>= \x2 ->
    dirac (x1 + x2)

--The next test is completely wrong. It's supposed to express something about
--the sum of n iid Exponential rvs. That's not the same thing as n times a single
--rv. 
t23 :: (ABT Term abt) => abt '[] ('HProb ':-> 'HProb ':-> 'HMeasure 'HProb)
t23 =
    lam $ \n ->
    lam $ \t ->
    exponential t >>= \x ->
    dirac (n * x)

--I can find no evidence for the truth of relationship t24. Indeed, it's
--trivial to prove false,
--t24 :: (ABT Term abt)
--    => abt '[] ('HProb ':-> 'HProb ':-> 'HProb ':-> 'HMeasure 'HProb)
--t24 =
--  lam $ \a ->
--  lam $ \b ->
--  lam $ \k ->
--  weibull a b >>= \x ->
--  dirac (k * x)

--The next test is wrong. The logs should be exps.
t25 :: (ABT Term abt) => abt '[]
    ('HReal ':-> 'HReal ':-> 'HProb ':-> 'HProb ':-> 'HMeasure 'HReal)
t25 =
    lam $ \mu1 ->
    lam $ \mu2 ->
    lam $ \sigma1 ->
    lam $ \sigma2 ->
    normal mu1 sigma1 >>= \x1 ->
    normal mu2 sigma2 >>= \x2 ->
    dirac (log x1 * log x2)

t26 :: (ABT Term abt) => abt '[] ('HReal ':-> 'HProb ':-> 'HMeasure 'HReal)
t26 =
    lam $ \l ->
    lam $ \s ->
    cauchy l s >>= \x ->
    dirac (recip x)

t27 :: (ABT Term abt)
    => abt '[] ('HProb ':-> 'HProb ':-> 'HProb ':-> 'HMeasure 'HProb)
t27 =
    lam $ \r ->
    lam $ \lambda ->
    lam $ \a ->
    gamma r lambda >>= \x ->
    dirac (a * x)

t28 :: (ABT Term abt) => abt '[] ('HProb ':-> 'HProb ':-> 'HMeasure 'HProb)
t28 =
    lam $ \a ->
    lam $ \b ->
    beta a b >>= \x ->
    dirac (one - x)

t29 :: (ABT Term abt) => abt '[] ('HInt ':-> 'HProb ':-> 'HMeasure 'HInt)
t29 =
    lam $ \n ->
    lam $ \p ->
    binomial n p >>= \x ->
    dirac (n - x)
