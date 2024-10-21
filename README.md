<!-- Improved compatibility of back to top link: See: https://github.com/othneildrew/Best-README-Template/pull/73 -->
<a id="readme-top"></a>
<!--
*** Thanks for checking out the Best-README-Template. If you have a suggestion
*** that would make this better, please fork the repo and create a pull request
*** or simply open an issue with the tag "enhancement".
*** Don't forget to give the project a star!
*** Thanks again! Now go create something AMAZING! :D
-->



<!-- PROJECT SHIELDS -->
<!--
*** I'm using markdown "reference style" links for readability.
*** Reference links are enclosed in brackets [ ] instead of parentheses ( ).
*** See the bottom of this document for the declaration of the reference variables
*** for contributors-url, forks-url, etc. This is an optional, concise syntax you may use.
*** https://www.markdownguide.org/basic-syntax/#reference-style-links
-->
<!--
[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
-->
[![Issues][issues-shield]][issues-url]
[![MIT License][license-shield]][license-url]



<!-- PROJECT LOGO -->
<br />
<div align="center">
  <!--a href="https://github.com/deas/argocd-conductr">
    <img src="images/logo.png" alt="Logo" width="80" height="80">
  </a-->

<h3 align="center">ArgoCD Conductr - GitOps Everything 🧪</h3>

  <p align="center">
    project_description
    <br />
    <a href="https://github.com/deas/argocd-conductr"><strong>Explore the docs »</strong></a>
    <br />
    <br />
    <!-- a href="https://github.com/deas/argocd-conductr">View Demo</a>
    ·
    -->
    <a href="https://github.com/deas/argocd-conductr/issues/new?labels=bug&template=bug-report---.md">Report Bug</a>
    ·
    <a href="https://github.com/deas/argocd-conductr/issues/new?labels=enhancement&template=feature-request---.md">Request Feature</a>
  </p>
</div>



<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#about-the-project">About The Project</a>
      <ul>
        <li><a href="#built-with">Built With</a></li>
      </ul>
    </li>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#prerequisites">Prerequisites</a></li>
        <li><a href="#installation">Installation</a></li>
      </ul>
    </li>
    <li><a href="#usage">Usage</a></li>
    <li><a href="#todo">Todo</a></li>
    <li><a href="#known-issues">Known Issues</a></li>
    <li><a href="#references">References</a></li>
    <li><a href="#license">License</a></li>
    <!--
    <li><a href="#contact">Contact</a></li>
    <li><a href="#acknowledgments">Acknowledgments</a></li>
    -->
  </ol>
</details>



<!-- ABOUT THE PROJECT -->
## About The Project

<!--
[![Product Name Screen Shot][product-screenshot]](https://example.com)
-->
<!--
Here's a blank template to get started: To avoid retyping too much info. Do a search and replace with your text editor for the following: `github_username`, `repo_name`, `twitter_handle`, `linkedin_username`, `email_client`, `email`, `project_title`, `project_description`

-->

The primary goal of this project is to exercise with ArgoCD based [GitOps](https://gitops.tech) deployment covering the full cycle - up to production via promotion, if you want to. Experimentation and production do not have to conflict.

The change process starts at localhost. Hence, we consider localhost experience (kind and maybe k3s soon) very important. Given that, some elements may be useful in CI context. Most things however, should play nice on produtive environments as well.

- YAML at scale is ... terrible.
- CI/CD usually horrible DX : “.. it’s this amalgamation of scripts in YAML tied together with duct tape.”
- Naming ... is hard
- Beware of Magic 🎩🪄🐰 (e.g. ArgoCD monitor apply)
- Beware of helm shared values or kustomize base. We deploy usually deploy main and shared bits kick in on all envs.
- Refs: Pin or Float?

### Goals
- Speed 🚀 (-> Notifications)
- Scalability
- kind, vanilla, crc, openshift  
- Simplicity (yes, really)
- Composability

### Non Goals
### Decisions
- Single level environment staging. Not reflected in names and namespaces. Because Matroka.

At the moment, we cover deployments of:
- Caretta
- Metallb
- Kube-Prometheus
- Loki/Promtail
- AWS Credentials Sync
- Sealed Secrets
- SOPS Secrets
- Submariner
- ArgoCD Notifications
- Argo-CD Image-Updater
- Argo Rollouts
- Argo Events
- ArgoCD (self managed)

<p align="right">(<a href="#readme-top">back to top</a>)</p>



### Built With

* [![Docker][Docker]][Docker-url]
* [![Terraform][Terraform]][Terraform-url]

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- GETTING STARTED -->
## Getting Started

This is an example of how you may give instructions on setting up your project locally.
To get a local copy up and running follow these simple example steps.

### Prerequisites

* make
* docker
  ```sh
  make
  ```
### Bootrapping
Generate encryption keys TODO:

```shell
./scripts/gen-keys.sh
```

Optional: Add public deployment key to github. You may also want to disable github actions to start.
```
gh repo deploy-key add ...
```

There is a `terraform` + `kind` based bootstrap in [`tf`](./tf):

```shell
cp sample.tfvars terraform.tfvars
# Set proper values in terraform.tfvars
make apply
```
should spin up an ArgoCD managed `kind` cluster.


### Installation

1. Clone the repo
   ```sh
   git clone https://github.com/deas/argocd-conductr.git
   ```
3. Install NPM packages
   ```sh
   npm install
   ```
4. Enter your API in `config.js`
   ```js
   const API_KEY = 'ENTER YOUR API';
   ```
5. Change git remote url to avoid accidental pushes to base project
   ```sh
   git remote set-url origin github_username/repo_name
   git remote -v # confirm the changes
   ```

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- USAGE EXAMPLES -->
## Usage

Use this space to show useful examples of how a project can be used. Additional screenshots, code examples and demos work well in this space. You may also link to more resources.

_For more examples, please refer to the [Documentation](https://example.com)_

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- TODO -->
## TODO
<!--
- [ ] Feature 1
- [ ] Feature 3
    - [ ] Nested Feature
-->

- `terraform`? (just like in `tf-controller`)
- crossplane
- keycloak + sso (DNS) local trickery
- `notify-send` desktop notifications (via webhook)
- Aspire Dashboard? (ultralight oTel)
- Customer Use Case Demo litmus?
- helm job sample
- ArgoCD Service Monitor (depends on prom)
- Canary-/Green/Blue Deployment (Rollouts)
- ~~default to auto update everything~~?
- ~~Proper self management of ArgoCD~~
- metrics-server
- contour?
- ~~cilium~~
- OPA Policies: _Gatekeeper vs usage in CI
- ArgoCD +/vs ACM/open cluster management
- Notifications Sync alerts slack/matrix
- Environment propagation
- Try to make sense of olm in our context[redhat-na-ssa/demo-argocd-gitops](https://github.com/redhat-na-ssa/demo-argocd-gitops). Appears the basic reason for olm would be the fact that many off the shelf helm charts simply don't play with openshift because redhat is doing their own thing? [Manage Kubernetes Operators with ArgoCD](https://piotrminkowski.com/2023/05/05/manage-kubernetes-operators-with-argocd/)? No, honestly.
- Try [Argo-CD Autopilot](https://argocd-autopilot.readthedocs.io/en/stable/)
- Proper cascaded removal. ArgoCD should be last. Will likely involve terraform. 
- [Applications in any namespace](https://argo-cd.readthedocs.io/en/stable/operator-manual/app-any-namespace/)(s. Known Issues)
- Service Account based OAuth integration on Openshift is nice - but tricky to implement: [OpenShift Authentication Integration with ArgoCD](https://cloud.redhat.com/blog/openshift-authentication-integration-with-argocd), [Authentication using OpenShift](https://dexidp.io/docs/connectors/openshift)
- Openshift Proxy/Global Pull Secrets
- Improve Github Actions Quality Gates
- Tracing Solution (zipkin, tempo) 
- oTel Sample
- Dashboards
- Consider migrating `make` to `just`
- [ocm solutions](https://github.com/open-cluster-management-io/ocm/tree/main/solutions)
See the [open issues](https://github.com/deas/argocd-conductr/issues) for a full list of proposed features (and known issues).

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Known Issues
- [Wildcards in ArgoCD sourceNamespaces prevent resource creation ](https://github.com/argoproj-labs/argocd-operator/issues/849)
- `argcocd` cli does not support apps with multiple sources.

### Speed / Registries
We want lifecycle of things (Create/Destroy) to be as fast as possible. Pulling images can slow things down significantly. Contrary docker a host based solution (such as `k3s`), challenges are harder with `kind`. Make sure to understand your the defails of your painpoints before implementing your solution.

- [Local Registry](https://kind.sigs.k8s.io/docs/user/local-registry/)
- [Pull-through Docker registry on Kind clusters](https://maelvls.dev/docker-proxy-registry-kind/) (`registry:2` supports only one registry per instnance)
- `kind load` may address some use cases
- Remove everything in `kind` installed by flux (so we can rebuild from cached images). (s. `make argocd-destroy`)

## References
- [Kustomized Helm (Application plugin)](https://medium.com/dzerolabs/turbocharge-argocd-with-app-of-apps-pattern-and-kustomized-helm-ea4993190e7c)
- [Bootstrapping: ApplicationSets vs App-of-apps vs Kustomize](https://github.com/argoproj/argo-cd/discussions/11892)
- [ArgoCD 2.10: ApplicationSet full templating](https://medium.com/@geoffrey.muselli/argocd-2-10-applicationset-full-templating-b94ce90fde96)
- [viaduct-ai/kustomize-sops](https://github.com/viaduct-ai/kustomize-sops)
- [Introduction to GitOps with ArgoCD](https://blog.codecentric.de/gitops-argocd)
- [3 patterns for deploying Helm charts with Argo CD](https://developers.redhat.com/articles/2023/05/25/3-patterns-deploying-helm-charts-argocd?sc_cid=7013a0000034Yq3AAE)
- [Self Managed Argo CD — App Of Everything](https://medium.com/devopsturkiye/self-managed-argo-cd-app-of-everything-a226eb100cf0)
- [Setting up Argo CD with Helm](https://www.arthurkoziel.com/setting-up-argocd-with-helm/)
- [terraform-argocd-bootstrap](https://github.com/iits-consulting/terraform-argocd-bootstrap)
- [ArgoCD with Kustomize and KSOPS using Age encryption](https://vikaspogu.dev/blog/argo-operator-ksops-age/)
- https://blog.devgenius.io/argocd-with-kustomize-and-ksops-2d43472e9d3b
- https://github.com/majinghe/argocd-sops
- https://dev.to/callepuzzle/secrets-in-argocd-with-sops-fc9
- [Argo CD Application Dependencies](https://codefresh.io/blog/argo-cd-application-dependencies/)
- [Progressive Syncs (alpha)](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Progressive-Syncs/)

<!-- CONTRIBUTING -->
## Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".
Don't forget to give the project a star! Thanks again!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

<p align="right">(<a href="#readme-top">back to top</a>)</p>
<!--
### Top contributors:

<a href="https://github.com/deas/argocd-conductr/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=github_username/repo_name" alt="contrib.rocks image" />
</a>
-->


<!-- LICENSE -->
## License

Distributed under the MIT License. See `LICENSE.txt` for more information.

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- CONTACT -->
<!--
## Contact

Your Name - [@twitter_handle](https://twitter.com/twitter_handle) - email@email_client.com

Project Link: [https://github.com/deas/argocd-conductr](https://github.com/deas/argocd-conductr)

<p align="right">(<a href="#readme-top">back to top</a>)</p>
-->


<!-- ACKNOWLEDGMENTS -->
<!--
## Acknowledgments

* []()
-->

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->
[contributors-shield]: https://img.shields.io/github/contributors/github_username/repo_name.svg?style=for-the-badge
[contributors-url]: https://github.com/deas/argocd-conductr/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/github_username/repo_name.svg?style=for-the-badge
[forks-url]: https://github.com/deas/argocd-conductr/network/members
[stars-shield]: https://img.shields.io/github/stars/github_username/repo_name.svg?style=for-the-badge
[stars-url]: https://github.com/deas/argocd-conductr/stargazers
[issues-shield]: https://img.shields.io/github/issues/github_username/repo_name.svg?style=for-the-badge
[issues-url]: https://github.com/deas/argocd-conductr/issues
[license-shield]: https://img.shields.io/github/license/github_username/repo_name.svg?style=for-the-badge
[license-url]: https://github.com/deas/argocd-conductr/blob/master/LICENSE.txt
[product-screenshot]: images/screenshot.png
[Docker]: https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white
[Docker-url]: https://www.docker.com/
[Terraform]: https://img.shields.io/badge/Terraform-%23623CE4.svg?style=for-the-badge&logo=terraform&logoColor=white
[Terraform-url]: https://www.terraform.io/
