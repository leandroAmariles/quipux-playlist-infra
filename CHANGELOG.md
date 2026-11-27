# Changelog

## [0.6.0](https://github.com/leandroAmariles/quipux-playlist-infra/compare/v0.5.1...v0.6.0) (2026-11-27)


### Features

* **HU-15:** bring up the local cluster and its AI services with make up ([f170a82](https://github.com/leandroAmariles/quipux-playlist-infra/commit/f170a823359712527b052624cd3205eb27ba6e3a))
* **HU-15:** bring up the local cluster with Terraform and make up ([ece5c4a](https://github.com/leandroAmariles/quipux-playlist-infra/commit/ece5c4a385375ec0ad6ce5ea573670f4b80870db))

## [0.5.1](https://github.com/leandroAmariles/quipux-playlist-infra/compare/v0.5.0...v0.5.1) (2026-11-27)


### Bug Fixes

* **compose:** keep idle LiteLLM connections open longer than the client ([d1be666](https://github.com/leandroAmariles/quipux-playlist-infra/commit/d1be6668e7acb8bcd0dfdc54fc5c77adfb5e2cd3))
* **compose:** keep idle LiteLLM connections open longer than the client ([dbf8f95](https://github.com/leandroAmariles/quipux-playlist-infra/commit/dbf8f956c259a50911f00cea2ade8a37b8e48f58))

## [0.5.0](https://github.com/leandroAmariles/quipux-playlist-infra/compare/v0.4.0...v0.5.0) (2026-11-27)


### Features

* **HU-14:** add self-hosted Langfuse to the AI composition ([93dae21](https://github.com/leandroAmariles/quipux-playlist-infra/commit/93dae2101304f3c1544722acdd4119836f5f4609))
* **HU-14:** add self-hosted Langfuse to the AI composition ([6b48c61](https://github.com/leandroAmariles/quipux-playlist-infra/commit/6b48c61368a208195f7130044389324b7488141c))


### Bug Fixes

* **HU-11:** check the Kafka port in the Compose healthcheck ([ecf6f55](https://github.com/leandroAmariles/quipux-playlist-infra/commit/ecf6f5590613c392606d5447d7a79642387e8e60))
* **HU-11:** let Kafka write its configuration in Kubernetes ([a2be24f](https://github.com/leandroAmariles/quipux-playlist-infra/commit/a2be24f6dadf0952ddaf8cdd83c71fe90c35a7c9))
* **HU-11:** make the Kafka service start and report health correctly ([f92f875](https://github.com/leandroAmariles/quipux-playlist-infra/commit/f92f875eddec4f4888b863f16188c39cf687e83d))

## [0.4.0](https://github.com/leandroAmariles/quipux-playlist-infra/compare/v0.3.0...v0.4.0) (2026-11-27)


### Features

* **HU-11:** add Kafka KRaft service to Docker Compose and Kubernetes ([6955146](https://github.com/leandroAmariles/quipux-playlist-infra/commit/6955146e36109fe34ebd52a2be964d8879614005))
* **HU-11:** add Kafka KRaft service to Docker Compose and Kubernetes ([6c71a13](https://github.com/leandroAmariles/quipux-playlist-infra/commit/6c71a135a791798ce84f35d1cf1aa32bd34ae457))

## [0.3.0](https://github.com/leandroAmariles/quipux-playlist-infra/compare/v0.2.0...v0.3.0) (2026-11-27)


### Features

* **HU-13:** pgvector and catalog indexing in the AI composition ([0863613](https://github.com/leandroAmariles/quipux-playlist-infra/commit/0863613592607d9507263a6f7351be4ac8483d9c))

## [0.2.0](https://github.com/leandroAmariles/quipux-playlist-infra/compare/v0.1.0...v0.2.0) (2026-11-27)


### Features

* **HU-10:** add Redis service to Docker Compose and Kubernetes ([7c0993d](https://github.com/leandroAmariles/quipux-playlist-infra/commit/7c0993deb0cda700f722e714764cd7d05312549e))
* **HU-10:** add Redis service to Docker Compose and Kubernetes ([05bbeae](https://github.com/leandroAmariles/quipux-playlist-infra/commit/05bbeaeab25dbcf41230c7e90a9e38438f08aeb2))

## 0.1.0 (2026-11-27)


### Features

* **HU-07:** run the whole application with Docker Compose ([1a8b8aa](https://github.com/leandroAmariles/quipux-playlist-infra/commit/1a8b8aa0a5c60789721e83a4f1b0ca1ac34c62d7))
* **HU-07:** run the whole application with Docker Compose ([3848849](https://github.com/leandroAmariles/quipux-playlist-infra/commit/38488497615b6d573ae2623c7d9fc71c0a410588))
* **HU-09:** add Argo CD Application manifest and fix nginx API_URL ([010c183](https://github.com/leandroAmariles/quipux-playlist-infra/commit/010c18371e8fd7945d3ab735bceedd8855ea822a))
* **HU-09:** add Argo CD Application manifest and fix nginx API_URL ([6840ef3](https://github.com/leandroAmariles/quipux-playlist-infra/commit/6840ef3e2668a7002c45b6c989c5074b9c0f8acc))
* **HU-09:** add Kubernetes Kustomize manifests and infra CI ([56a2a49](https://github.com/leandroAmariles/quipux-playlist-infra/commit/56a2a49792eb7b32300a926ce5b60466c0545ac2))
* **HU-09:** add Kubernetes Kustomize manifests and infra CI ([ae8dd10](https://github.com/leandroAmariles/quipux-playlist-infra/commit/ae8dd1010a5f7d8a35187489629416f0cdffcbd5))
* **HU-09:** configure release-please for infra repository ([4f7a01e](https://github.com/leandroAmariles/quipux-playlist-infra/commit/4f7a01ef5c6da7be0a5a8b304affb4daf0b41d48))
* **HU-09:** configure release-please for infra repository ([c4b139e](https://github.com/leandroAmariles/quipux-playlist-infra/commit/c4b139ef26e74e1a52455b43550c70c615ea41ad))
* **HU-12:** run local models behind LiteLLM with Docker Compose ([ed5f9f2](https://github.com/leandroAmariles/quipux-playlist-infra/commit/ed5f9f20fd1a5975e2438aa3f4711705f760364b))
* **HU-12:** run the local AI models with Docker Compose ([1e6730f](https://github.com/leandroAmariles/quipux-playlist-infra/commit/1e6730f3d75ba76c170099b3c44570473cfbfadc))
