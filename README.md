# authorino-examples

Examples of Authorino [`AuthConfig`](https://github.com/kuadrant/authorino/blob/docs/architecture.md#the-authorino-authconfig-custom-resource-definition-crd) custom resources, applications and deployment manifests used in demos and tutorials of [Authorino](https://github.com/kuadrant/authorino).

Please refer to the Authorino [User guides](https://github.com/kuadrant/authorino/blob/main/docs/user-guides.md) for usage instructions related to most of the resources included in this repo.

## Custom apps and deployments

For each application below, you will usually find a `*-deploy.yaml` file in the corresponding directory of the application. This file contains the required manifests to deploy the application to a Kubernetes cluster.

### Talker API

Just another echo API that responds as JSON whatever attributes it gets in the original HTTP request.

<table>
 <tbody>
    <tr>
      <th>Image:</th>
      <td><a href="https://quay.io/kuadrant/authorino-examples:talker-api"><code>quay.io/kuadrant/authorino-examples:talker-api</code></a></td>
    </tr>
  </tbody>
</table>

### News API

The News Agency API ("News API" for short) is a REST API to manage news articles (Create, Read, Delete), with no embedded concept of authentication or authorization. Records are stored in memory (default) or in a Redis database (by supplying a `REDIS_URL` environment variable).

HTTP endpoints available:
```
POST /{category}          Create a news article
GET /{category}           List news articles
GET /{category}/{id}      Read a news article
DELETE /{category}/{id}   Delete a news article
```

A news article is structured as follows:

```jsonc
{
  "id": <string: auto-generated>,
  "title": <string>,
  "body": <string>,
  "date": <string: ISO 8601>,
  "author": <string>,
  "user_id": <string>
}
```

In the requests to `POST /{category}`, `author` and `user_id` can be supplied in either of 2 supported HTTP headers:
- `X-Ext-Auth-Data`: stringified JSON containing at least the `author` and the `user_id` properties;
- `X-Ext-Auth-Wristband`: an Authorino [Festival Wrisband](https://github.com/Kuadrant/authorino/blob/main/docs/features.md#festival-wristband-tokens-responsewristband) token whose `name` and `sub` claims map respectively to `author` and the `user_id`.

<table>
 <tbody>
    <tr>
      <th>Image:</th>
      <td><a href="https://quay.io/kuadrant/authorino-examples:news-api"><code>quay.io/kuadrant/authorino-examples:news-api</code></a></td>
    </tr>
  </tbody>
</table>

### Envoy

Kubernetes manifests to deploy Envoy proxy – `ConfigMap`, `Deployment`, `Service` and `Ingress`.

The `ConfigMap` contains an Envoy configuration to put the [Talker API](#talker-api) (`http://*:8000/ → talker-api:3000`) and the [Talker Web](talker-web) (`http://*:8000/web → http://talker-web:888`) apps behind the reverse-proxy. It also sets up Authorino (`authorino-authorino-authorization:50051`) and [Limitador](#limitador) (`limitador:8081`), respectively, in the external authorization and rate limiting HTTP filters.

The config is provided in two flavors (kustomize overlays): TLS and no-TLS enabled in the Authorino endpoints (gRPC ext-authz and Wirstband OIDC discovery). When TLS is enabled, the deployment expects the Authorino certificates to be stored in an `authorino-ca-cert` `Secret`.

The rate limit configuration has `failure_mode_deny: false`, which means that requests will only be rate limited when Limitador is running. If Authorino cannot be reached, on the other hand, requests will be rejected with a `403 Forbidden` response.

The external authorization filter is disabled for the endpoints of the Talker Web app.

<table>
 <tbody>
    <tr>
      <th>Image:</th>
      <td><a href="https://hub.docker.com/r/envoyproxy/envoy/tags/?page=1&name=v1.19-latest"><code>envoyproxy/envoy:v1.19-latest</code></a></td>
    </tr>
  </tbody>
</table>

### Keycloak

A bundle with Kubernetes manifests to deploy a [**Keycloak**](https://www.keycloak.org) server, preloaded with the following realm setup:<br/>
- Admin console: http://localhost:8080/auth/admin (admin/p)
- Preloaded realm: **kuadrant**
- Preloaded clients:
  - **demo**: to which API consumers delegate access and therefore the one which access tokens are issued to
  - **talker-api**: used by Authorino to fetch UMA-protected resource data associated with the Talker API (Client secret: 523b92b6-625d-4e1e-a313-77e7a8ae4e88)
- Preloaded resources (`talker-api` client):
  - `/hello`
  - `/greetings/1` (owned by user jonh)
  - `/greetings/2` (owned by user jane)
  - `/goodbye`
- Preloaded authorization scopes (`talker-api` client):
  - `get`
  - `post`
  - `put`
  - `delete`
- Realm roles:
  - member (default to all users)
  - admin
- Preloaded users:
  - john/p (member)
  - jane/p (admin)
  - peter/p (member, email not verified)

<table>
 <tbody>
    <tr>
      <th>Image:</th>
      <td><a href="quay.io/kuadrant/authorino-examples:keycloak-15.0.2"><code>quay.io/kuadrant/authorino-examples:keycloak-15.0.2</code></a></td>
    </tr>
  </tbody>
</table>

### Dex

A bundle with Kubernetes manifests to deploy a [**Dex**](https://dexidp.io) server, preloaded with the following setup:<br/>
- Preloaded clients:<br/>
  - **demo**: to which API consumers delegate access and therefore the one which access tokens are issued to (Client secret: aaf88e0e-d41d-4325-a068-57c4b0d61d8e)
- Preloaded users:<br/>
  - marta@localhost/password

<table>
 <tbody>
    <tr>
      <th>Image:</th>
      <td><a href="https://quay.io/dexidp/dex:v2.26.0"><code>quay.io/dexidp/dex:v2.26.0</code></a></td>
    </tr>
  </tbody>
</table>

### a12n-server

A bundle with Kubernetes manifests to deploy a [**a12n-server**](https://github.com/curveball/a12n-server) server and corresponding MySQL database, preloaded with the following setup:<br/>
- Admin console: http://a12n-server:8531 (admin@demo/123456)
- Preloaded clients:<br/>
  - **service-account-1**: to obtain access tokens via `client_credentials` OAuth2 grant type, to consume the Talker API (Client secret: DbgXROi3uhWYCxNUq_U1ZXjGfLHOIM8X3C2bJLpeEdE); includes metadata privilege: `{ "talker-api": ["read"] }` that can be used to write authorization policies
  - **talker-api**: to authenticate to the token introspect endpoint (Client secret: V6g-2Eq2ALB1_WHAswzoeZofJ_e86RI4tdjClDDDb4g)

<table>
 <tbody>
    <tr>
      <th>Images:</th>
      <td>
        <a href="https://quay.io/kuadrant/authorino-examples:a12n-server"><code>quay.io/kuadrant/authorino-examples:a12n-server</code></a><br/>
        <a href="https://quay.io/kuadrant/authorino-examples:a12n-server-mysql"><code>quay.io/kuadrant/authorino-examples:a12n-server-mysql</code></a>
      </td>
    </tr>
  </tbody>
</table>

### Talker Web

Node.js Single Page Application (SPA) that consumes resources of the [Talker API](#talker-api) from a web browser.

URL behind Envoy: http://talker-api-authorino.127.0.0.1.nip.io:8000/web

<table>
 <tbody>
    <tr>
      <th>Image:</th>
      <td><a href="https://quay.io/kuadrant/authorino-examples:talker-web"><code>quay.io/kuadrant/authorino-examples:talker-web</code></a></td>
    </tr>
  </tbody>
</table>

### Matrix Quotes

Node.js web application that gathers quotes from characters of the film _The Matrix_ (1999).

If you haven't watched The Matrix yet, stop what you are doing, go watch it now, and then come back 🙂

<table>
 <tbody>
    <tr>
      <th>Image:</th>
      <td><a href="https://quay.io/kuadrant/authorino-examples:matrix-quotes"><code>quay.io/kuadrant/authorino-examples:matrix-quotes</code></a></td>
    </tr>
  </tbody>
</table>

### API consumer

Simple script that curls a given endpoint in a loop, every X seconds. It only sends `GET` requests.

Arguments:
- `--endpoint`: the endpoint to send requests to;
- `--token`: the value of the authentication token;
- `--token-path`: path to an authentication token file monted in the file system;
- `--credentials-in`: where the authentication token must fly in the request (options: `authorization_header`, `custom_header`, `cookie`, `query`; default: `authorization_header`);
- `--credentials-key`: additional value to `--credentials-in` – the authorization header prefix, name of custom header, cookie id or query string parameter (default: `Bearer`);
- `--interval`: interval (in seconds) between requests.

<table>
 <tbody>
    <tr>
      <th>Image:</th>
      <td><a href="https://quay.io/kuadrant/authorino-examples:api-consumer"><code>quay.io/kuadrant/authorino-examples:api-consumer</code></a></td>
    </tr>
  </tbody>
</table>

### IP Location

Simple service to resolve an IPv4 address into geo location info.

<table>
 <tbody>
    <tr>
      <th>Image:</th>
      <td><a href="https://quay.io/kuadrant/authorino-examples:ip-location"><code>quay.io/kuadrant/authorino-examples:ip-location</code></a></td>
    </tr>
  </tbody>
</table>

### Limitador

Kubernetes manifests to deploy [**Limitador**](https://github.com/kuadrant/limitador), pre-configured in the [reverse-proxy](#envoy) to rate-limit the [Talker API](#talker-api) app to 5 hits per minute per `user_id`.

<table>
 <tbody>
    <tr>
      <th>Image:</th>
      <td><a href="https://quay.io/3scale/limitador:latest"><code>quay.io/3scale/limitador:latest</code></a></td>
    </tr>
  </tbody>
</table>
