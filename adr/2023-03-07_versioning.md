# versioning

## Status <!-- What is the status, such as proposed, accepted, rejected, deprecated, superseded, etc.? -->

accepted

## Context <!-- What is the issue that we're seeing that is motivating this decision or change? -->

- we needed to find a good versioning for this image
- thinks to consider were
    - this image is a fork / customization of registry.k8s.io/dns/k8s-dns-node-cache:1.22.20
        - keeping the k8s-dns version in our version & equal to the version extracted from https://github.com/kubernetes/kubernetes/blob/3b17aece1fa492e98aa82b948597b3641961195f/cluster/addons/dns/nodelocaldns/nodelocaldns.yaml seemed like a good idea
    - how renovateBot is supporting semVer-like versions for container images
        - see [renovatebot docker versioning](https://docs.renovatebot.com/modules/versioning/#docker-versioning)
          > Renovate tries to follow the most common conventions that are used to tag Docker images. In particular, Renovate treats the text after the first hyphen (`-`) as a type of platform/compatibility indicator.
        - see [regex versioning](https://docs.renovatebot.com/modules/versioning/#regular-expression-versioning)
            - uses ` regex capture groups`, valid groups are:
                - `major`, `minor`, and `patch`
                - `build`
                - (not relevant for us, not used) `prerelease`
                - `compatibility`
    - git tage vs docker tag
        - the docker tag format
            > A tag name must be valid ASCII and may contain
            > lowercase and uppercase letters, digits, underscores, periods and hyphens.
            > A tag name may not start with a period or a hyphen and may contain a maximum of 128 characters.
        - how does semVer handles a build version (git)
            - ...
    - how to handle versioining when code change in this repo
        - issue with the first approach was that it only considered kubedns and iptables version for image versioning
            - that would overwrite tag/image when the docker file e.g. changes but the k8s-dns and iptables versions stay the same
        - the question is: should a source-code change in the repo be handled as a new version (git version - but more importantly container image version)
            - when yes, how to properly handle the versioing
                - options found:
                    - custom git version (`0.1.0`), equally used for the conatiner image tag
                    - semVer approch, including the original kube-dns version plus our / a custom `build` version, which represents the repository changes but also reflects that this is a fork / overwrite of the default k8s images
- git tag - version options
    - no tagging
    - ``0.1.0`
    - `1.22.1+build.23`
        - inlcuding k8s-dns in the first part
- docker tag - version options
    - 1st idea
        - `1.21.1` (just using the k8s-dns version)
        - `1.21.1-iptables1.8.8` (k8s-dns & iptables version)
        - `1.21.1-iptables1.8.8-r1` (same as before, but adding linux build thing for iptables)
    - 2nd
        - `0.1.0`(complete new version based on the repo)
        - `1.21.1-build23` TODO ??? in default for renovate `-` is compatibility indictor, not build indicator (would need regex versioning?) ??? (keeping the k8s-dens version, adding own build version)
        - `1.21.1-iptables1.8.8-build` TODO
        - `1.21.1-build.23` TODO
        - `1.21.1.build.23` TODO

## Decision <!-- What is the change that we're proposing and/or doing? -->
- git versioning/tag like:
```
1.22.1+build.23
\    /|\      /
 \  / |  \  /
  ||  |   ||
  ||  |   ||
  ||  |   our build version
  ||  |
  ||  plus seperator
  ||
k8s-dns version
```

- docker versioning/tag like:
(plus becomes a hypen, as plus is not supported in docker tags):
```
1.22.1-build.23
\    /|\      /
 \  / |  \  /
  ||  |   ||
  ||  |   ||
  ||  |   our build version
  ||  |
  ||  hypen (`-`) seperator
  ||
k8s-dns version
```

- using: renovatebot custom regex versioning for container images
    - not using: renovate "default docker versioning" vs
    - reason:
        - the "default docker versioing" would force us to use (exploit) the `prerelease` behaviour for our `build` versioining
        - with the "regex versioning", altough it needs more effort to implmenet correctly, it allows us to present a more correct way of our intendet versioing using `build` versions for container image tagging, being closer to actual semVer (although the fact that `+` is not supported for container image tags)

## Consequences <!-- What becomes easier or more difficult to do because of this change? -->
