In this series, we are exploring the steps we took to build a [student project platform](https://huddle.hsg.fs.tum.de) where students can share their sideprojects and explore what their peers are doing.
After looking at the [architecture of our GraphQL backend](https://dev.to/peteole/how-we-built-a-student-project-platform-using-graphql-react-golang-ory-kratos-and-kubernetes-part-1-19jg) and [how we consume it in a typesafe way](https://dev.to/peteole/how-we-built-a-student-project-platform-using-graphql-react-golang-ory-kratos-and-kubernetes-part-1-19jg), we will take a deeper dive into authentication.
# High-level architecture
We have three software components that are involved in the authentication process:

1. The React UI. The user enters their password here and wants to see their protected data
2. The GraphQL API. The API wants to verify that requests that need authentication really come from the user the request claims to come from. Located in our kubernetes cluster
3. Ory Kratos. Kratos manages user login credentials. Located in our kubernetes cluster, too.

Since I have been confused by it in the beginning, I created an image of all the messages sent in a typical login:
![Images sent during login](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/7jbo8myhuflr9qm9tfxw.png)

## Flows
Ory Kratos often works with so-called _flows_. A flow is a process that my consist of several steps such as account recovery or login (with MFA in the future). For login with username/password this may seem like an overkill since there is only a singe request (send credentials in exchange for session cookie), but I expect the flow pattern is used here to allow for MFA logins in the future.

So the login is as follows:

1. Request a login flow
2. Kratos returns login flow ID
3. Send login to kratos, referencing the flow ID
4. Kratos returns session cookie
5. Request protected field from GQL api, attaching session cookie
6. GQL API asks kratos to verify session cookie
7. Kratos returns user ID belonging to session cookie
8. GQL API returns protected field

## Redirects / Account recovery
Sometimes, Kratos and the user interface need another concept to interact. Let's say you forgot your password and requested a recovery link via mail. The problem kratos developers needed to solve here is to send some _token_ from the recovery link back to kratos (to verify the email) and at the same time associate it with a session of the UI in a web browser so that the user can reset their password in the UI, and all with minimal knowledge of the specific app architecture.

They solved this by hosting kratos on the same domain as the app itself and using _redirects_. For instance our UI is hosted under https://huddle.hsg.fs.tum.de/ui whereas kratos is hosted under https://huddle.hsg.fs.tum.de/.ory/kratos. The messages exchanged are as follows:

1. User clicks recovery link in the format https://huddle.hsg.fs.tum.de/.ory/kratos/self-service/recovery?flow=6b817dhf-4717-48we-a756-cd7902b43ce6&token=QiGjssJcvB08H7cUdE3tyXvQr1i4OSaR. Note that this will result in a GET request by the browser that will be handled by kratos totally independent from the UI!
2. Kratos verifies the query parameters and responds with a redirect to a preconfigured URL such as https://huddle.hsg.fs.tum.de/ui/profile. A session cookie is set as well so that future requests by the user can be authenticated
3. After the redirect, the web application UI takes over. For instance the user can set a new password on the profile site.

# Deployment and secret management

Let's first go through the deployment of ory kratos itself, which we do in [kubernetes](https://kubernetes.io/) with [helm](https://helm.sh/) and [helmfile](https://github.com/roboll/helmfile).

Kratos has a [helm chart](https://k8s.ory.sh/helm/kratos.html) that allows to install kratos in a cluster more or less conveniently. The interesting thing is how to configure kratos (set redirect links, email-credentials etc.). We to it by providing values to the helm chart in our helmfile. All this is managed in our [deployment repo](https://gitlab.lrz.de/projecthub/deployment):
```txt
├── cert.yaml
├── database
│   ├── migrate.sh
     ...
├── database.yml
├── deployment.yaml
├── helmfile.yaml
├── kratos.yml
└── userSchema.json
...
```
The entrypoint for the kratos deployment is `helmfile.yaml`:
```yaml
repositories:
...
  - name: ory
    url: https://k8s.ory.sh/helm/charts

releases:
...

  - name: kratos
    chart: ory/kratos
    values:
      - kratos.yml
```
Note how the configuration itself is loaded from another file, `kratos.yml`:
```yaml
kratos:
  config:
    courier:
      smtp:
        from_address: huddle.bot@zohomail.eu
        from_name: Huddle
    identity:
        default_schema_url: base64://ewogICAgIiRpZCI6ICJodHRwczovL2dpdGxhYi5scnouZGUvcHJvamVjdGh1Yi9zY2hlbWEtdXNlci1rcmF0b3MuanNvbiIsCiAgICAiJHNjaGVtYSI6ICJodHRwOi8vanNvbi1zY2hlbWEub3JnL2RyYWZ0LTA3L3NjaGVtYSMiLAogICAgInRpdGxlIjogIlBlcnNvbiIsCiAgICAidHlwZSI6ICJvYmplY3QiLAogICAgInByb3BlcnRpZXMiOiB7CiAgICAgICAgInRyYWl0cyI6IHsKICAgICAgICAgICAgInR5cGUiOiAib2JqZWN0IiwKICAgICAgICAgICAgInByb3BlcnRpZXMiOiB7CiAgICAgICAgICAgICAgICAiZW1haWwiOiB7CiAgICAgICAgICAgICAgICAgICAgInR5cGUiOiAic3RyaW5nIiwKICAgICAgICAgICAgICAgICAgICAiZm9ybWF0IjogImVtYWlsIiwKICAgICAgICAgICAgICAgICAgICAib3J5LnNoL2tyYXRvcyI6IHsKICAgICAgICAgICAgICAgICAgICAgICAgImNyZWRlbnRpYWxzIjogewogICAgICAgICAgICAgICAgICAgICAgICAgICAgInBhc3N3b3JkIjogewogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICJpZGVudGlmaWVyIjogdHJ1ZQogICAgICAgICAgICAgICAgICAgICAgICAgICAgfQogICAgICAgICAgICAgICAgICAgICAgICB9LAogICAgICAgICAgICAgICAgICAgICAgICAidmVyaWZpY2F0aW9uIjogewogICAgICAgICAgICAgICAgICAgICAgICAgICAgInZpYSI6ICJlbWFpbCIKICAgICAgICAgICAgICAgICAgICAgICAgfSwKICAgICAgICAgICAgICAgICAgICAgICAgInJlY292ZXJ5IjogewogICAgICAgICAgICAgICAgICAgICAgICAgICAgInZpYSI6ICJlbWFpbCIKICAgICAgICAgICAgICAgICAgICAgICAgfQogICAgICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgICAgIH0sCiAgICAgICAgICAgICAgICAidXNlcm5hbWUiOiB7CiAgICAgICAgICAgICAgICAgICAgInR5cGUiOiAic3RyaW5nIiwKICAgICAgICAgICAgICAgICAgICAib3J5LnNoL2tyYXRvcyI6IHsKICAgICAgICAgICAgICAgICAgICAgICAgImNyZWRlbnRpYWxzIjogewogICAgICAgICAgICAgICAgICAgICAgICAgICAgInBhc3N3b3JkIjogewogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICJpZGVudGlmaWVyIjogdHJ1ZQogICAgICAgICAgICAgICAgICAgICAgICAgICAgfQogICAgICAgICAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgICAgICAgICAgfQogICAgICAgICAgICAgICAgfQogICAgICAgICAgICB9CiAgICAgICAgfQogICAgfQp9
        schemas: []
    selfservice:
      default_browser_return_url: https://huddle.hsg.fs.tum.de/ui
      methods:
        link:
          enabled: true
      flows:
        settings:
          ui_url: https://huddle.hsg.fs.tum.de/ui/
        verification:
          ui_url: https://huddle.hsg.fs.tum.de/ui/verification
          enabled: true
        recovery:
          enabled: true
          ui_url: https://huddle.hsg.fs.tum.de/ui/profile
    serve:
      public:
        base_url: https://huddle.hsg.fs.tum.de/.ory/kratos
        cors:
          enabled: true
          allowed_origins:
            - https://huddle.hsg.fs.tum.de
            - https://huddle.ridilla.eu
            - http://localhost:3000
  autoMigrate: true
secret:
  # -- switch to false to prevent creating the secret
  enabled: false
  # -- Provide custom name of existing secret, or custom name of secret to be created
  nameOverride: secret-kratos
```
This config consists of two parts: 

1. The `kratos.config` subfields follow the schema for configuring kratos independent from kubernetes, as described [here](https://www.ory.sh/docs/kratos/reference/configuration). As you can see we set various fields such as the email address to use for account recovery, the url to redirect to after recovery and the [identity schema to use for storing account data](https://www.ory.sh/docs/kratos/concepts/identity-schema) in base 64 encoding.
2. The `secret` subfields are used for a kubernetes-specific way to provide credentials since we don't want to save them in plain text. We state that kratos should use a secret called `secret-kratos` to get credentials rather than try to take them from the plain text config. This allows us to create the secret in another, encrypted repo (meaning only encrypted versions of the secrets are tracked with git). The `secret-kratos`-secret has to be in the following format:
```yaml
kind: Secret
metadata:
  name: secret-kratos
type: Opaque
apiVersion: v1
stringData:
  dsn: postgres://kratos:cmoaincsieadfo@psql-postgresql:5432/kratos
  secretsCipher: nasdlifuhlaiwd
  secretsCookie: lnaslicWERUOZSdicbl
  secretsDefault: ANSIULccbASKNXKAJ
  smtpConnectionURI: smtps://huddle.bot@zohomail.eu:qnIAsdHmsuU@smtp.zoho.eu:465
```
(of course I replaced the credentials by hitting the keyboard as wild :smiley:)

Now running `helmfile sync` will deploy kratos to our cluster!

Finally we need to publicly expose kratos using an ingress controller in kubernetes:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kratos-ingress
  annotations:
    kubernetes.io/ingress.class: "nginx"   
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  tls:
  - hosts:
      - huddle.ridilla.eu
    secretName: huddle-ridilla-eu-prod-tls
  - hosts:
      - huddle.hsg.fs.tum.de
    secretName: huddle-hsg-fs-tum-de-prod-tls
  rules:
  - host: huddle.hsg.fs.tum.de
    http:
      paths:
      - path: /.ory/kratos(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: kratos-public
            port:
              number: 80
```
However two things feel a bit hacky about the deployment:

1. Even though we correctly set the base URL in the kratos config, we need to do [regex magic to rewrite the path as if kratos was hosted under the root path](https://kubernetes.github.io/ingress-nginx/user-guide/ingress-path-matching/).
2. I was unable to find a way to put the kratos config in its own file (which would for instance enable intellisense in VSCode) and include that file as a subfield of the `kratos.config` field of the helm config
3. Running `helmfile sync` after altering some kratos preferences does NOT deploy these changes to the cluster. You need to delete the kratos deployment and then run the sync comment.

Do you have any tips on how to solve this?

# The login UI
Now let's jump right into the code! We handle login requests with a popup component that looks like this:
![Authentication popup](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/fqp8v5gn67b44j7skowx.png)
 The component receives an observable of so-called "login request" as a property. By default it's hidden. Whenever a login requests drops in (since a user clicked an item that needs authorization), the component pops up and asks the user to fill in their credentials, register or reset their password. When the credentials are entered, the corresponding flow is started using the [kratos js sdk](https://www.ory.sh/docs/kratos/sdk).
```tsx
import React, { useEffect, useState } from 'react';
import type { Identity, UiContainer, V0alpha2Api } from '@ory/kratos-client'
let _api: V0alpha2Api | undefined
export const getAPI = async () => {
    // allow for code splitting since the kratos sdk is large
    if (!_api) {
        const { V0alpha2Api, Configuration } = await import("@ory/kratos-client")
        const kratosConfig = new Configuration({
            basePath: clientConfig.kratosUrl,
            baseOptions: {
                withCredentials: true
            }
        });
        _api = new V0alpha2Api(kratosConfig);
    }
    return _api
}
import './AuthenticationManagerPopup.css'
import { AuthenticationRequest } from './authenticationObserbale';
import { Observable, useApolloClient } from '@apollo/client';
import Button from '../shared/Button';
import Input from '../shared/Input';
import { clientConfig } from "../config"
import { Link } from 'react-router-dom';
import { useGetMeWithoutLoginPromptQuery } from '../schemas';
export const AuthenticationManagerPopup: React.FC<{ a: Observable<AuthenticationRequest> }> = (props) => {
    const meData = useGetMeWithoutLoginPromptQuery() // This should actually never be needed when the popup is shown
    const client = useApolloClient()
    const [authRequests, setAuthRequests] = useState<AuthenticationRequest[]>([])
    const [email, setEmail] = useState("")
    const [password, setPassword] = useState("")
    useEffect(() => {
        // listen for authentication requests on component creation...
        const subscription = props.a.subscribe(req => {
            setAuthRequests([...authRequests, req])
        })
        // ... and clean up when the component is unmounted
        return () => {
            subscription.unsubscribe()
        }
    }, [])
    if (authRequests.length === 0) {
        return null
    }
    return (
        <div id="authentication-manager-popup">
            <div>
                <h1>Authentication Panel</h1>
                {meData.data?.meIfLoggedIn && <p>Hello {meData.data.meIfLoggedIn?.username}, old friend!</p>}
                <br />
                <Input onChange={setEmail} description='email' autoComplete='email' />
                <br />
                <Input onChange={setPassword} description='Password' autoComplete='current-password' type='password' />
                <br />
                <Button filled disabledMessage={email.length === 0 || password.length === 0 ? "Please enter your email address and desired password above to register" : undefined}
                    onClick={async () => {
                        try {
                            console.log('registering user');
                            const api = await getAPI()
                            const resp = await api.initializeSelfServiceRegistrationFlowForBrowsers()
                            console.log(resp.data);
                            if (!resp) return
                            const registrationFlowId = resp.data.id;
                            const csrf_token = (resp.data.ui.nodes[0].attributes as { value: string }).value;

                            const registrationResponse = await api.submitSelfServiceRegistrationFlow(registrationFlowId, {
                                method: "password",
                                password: password,
                                traits: {
                                    email: email
                                },
                                csrf_token: csrf_token
                            })
                            console.log(registrationResponse.data);
                            resp.data.ui
                            api.initializeSelfServiceVerificationFlowForBrowsers().then(resp => {
                                console.log(resp.data);
                                const csrf_token = (resp.data.ui.nodes[0].attributes as { value: string }).value;
                                api.submitSelfServiceVerificationFlow(resp.data.id, undefined, {
                                    method: "link",
                                    email: email,
                                    csrf_token
                                }).then(resp => {
                                    console.log(resp.data);
                                    client.refetchQueries({
                                        include: "active",
                                    });
                                })
                            })
                        } catch (e) {
                            alertUnknownError(e)
                        }
                    }}>register</Button>
                <p>or</p>
                <br />
                <Button filled disabledMessage={email.length === 0 || password.length === 0 ? "Please enter your email address and password above to log in" : undefined}
                    onClick={async () => {
                        try {
                            console.log('login');
                            const api = await getAPI()
                            const resp = await api.initializeSelfServiceLoginFlowForBrowsers()
                            console.log(resp.data);
                            if (!resp) return
                            const csrf_token = (resp.data.ui.nodes[0].attributes as { value: string }).value;

                            const loginResponse = await api.submitSelfServiceLoginFlow(resp.data.id, undefined, {
                                method: "password",
                                password: password,
                                password_identifier: email,
                                csrf_token: csrf_token
                            })
                            console.log(loginResponse.data);
                            authRequests.forEach(r => r.onFinished())
                            setAuthRequests([])
                            client.refetchQueries({ include: "all" })
                        } catch (error) {
                            alertUnknownError(error)
                        }
                    }}>login</Button>
                <p>By registering, you consent to the <Link target="_blank" to="/about">data we collect and our terms of use</Link>. </p>
                <Button disabledMessage={email.length === 0 ? "Please enter your email address above to recover your account" : undefined}
                    onClick={async () => {
                        try {
                            console.log('trying to recover account');
                            const api = await getAPI()
                            const resp = await api.initializeSelfServiceRecoveryFlowForBrowsers()
                            console.log(resp.data);
                            if (!resp) return
                            const loginFlowId = resp.data.id;
                            const csrf_token = (resp.data.ui.nodes[0].attributes as { value: string }).value;

                            const recoveryResponse = await api.submitSelfServiceRecoveryFlow(resp.data.id, undefined, {
                                method: "link",
                                email,
                                csrf_token
                            })
                            console.log(recoveryResponse.data);
                            authRequests.forEach(r => r.onFinished())
                            setAuthRequests([])
                        } catch (error) {
                            alertUnknownError(error)
                        }
                    }}>reset password</Button>
                <br />
                <Button onClick={() => {
                    authRequests.forEach(r => r.onFailed("User closed window"))
                    setAuthRequests([])
                }}>close</Button>
            </div>
        </div>
    )
}

export const logout = async () => {
    console.log('logout');
    const api = await getAPI()
    const resp = await api.createSelfServiceLogoutFlowUrlForBrowsers()
    console.log(resp.data);
    if (!resp) return
    const logoutResponse = await api.submitSelfServiceLogoutFlow(resp.data.logout_token)
    console.log(logoutResponse.data);
}
export const LogoutButton: React.FC = props => {
    return (
        <Button onClick={logout}>Logout</Button>
    )
}
...
```
Is there a nicer way to handle the CSRF token? This feels a bit hacky...

Right now, the flows can be finished without any further human interventions since they consist only of one step, but this may change with 2FA.

The missing part that I find really cool is how the popup is triggered. We do this by a clever configuration of the Apollo client with [Links](https://www.apollographql.com/docs/react/api/link/introduction/):
```ts
import { HttpLink, ApolloClient, InMemoryCache, ApolloLink, Observable } from "@apollo/client";
import { offsetLimitPagination } from "@apollo/client/utilities";
import PushStream from "zen-push"
import { AuthenticationRequest } from "./authentication/authenticationObserbale";
import {clientConfig}  from "./config";
import { StrictTypedTypePolicies } from "./schemas";

const endpointLink = new HttpLink({
    uri: clientConfig.gqlUrl,
    credentials: "include"
});
// Subscribe to this to display the authentication popup when needing authentication
export const authenticationStream = new PushStream<AuthenticationRequest>();
const LoginLink = new ApolloLink((operation, forward) => {
    const observable = endpointLink.request(operation);
    let waitingForLogin = false
    return new Observable((observer) => {
        // subscribe to http link and handle authentication errors seperately
        const subs = observable!.subscribe({
            next: (data) => {
                if (data.errors?.[0]?.message.includes("authenticate")) {
                    waitingForLogin = true
                    // Ask for login
                    authenticationStream.next({
                        onFailed: () => {
                            observer.next(data)
                            waitingForLogin = false
                        },
                        onFinished: () => {
                            // retry fetching data after authentication
                            subs.unsubscribe()
                            endpointLink.request(operation)?.subscribe({
                                next: data => observer.next(data),
                                complete: () => observer.complete(),
                                error: (err) => observer.error(err)
                            })
                        }
                    })
                } else {
                    // forward data
                    observer.next(data);
                }
            },
            error: (error) => {
                observer.error(error);
            }
            ,
            complete: () => {
                if (!waitingForLogin) {
                    observer.complete();
                }
            }
        });
    });
});
const typePolicies: StrictTypedTypePolicies={
    Project:{
        keyFields:["id"],
        merge(existing, incoming) {
            return { ...existing, ...incoming };
        }
    },
    Query:{
        fields:{
            searchProjects:offsetLimitPagination(["options","searchString"])
        }
    }
}
export const client = new ApolloClient({
    // uri: 'https://huddle.ridilla.eu/api/query',
    cache: new InMemoryCache({typePolicies}),
    link: LoginLink
});
```
We hook into the http requests sent to our API and whenever an error contains the word "authentication", we ask our user to log in by pushing in the `authenticationStream`, which is passed to our instance of the `AuthenticationPopup` component.

The nice thing is that in the rest of the UI, we have no other point, where we need to care about authentication! Just make your GraphQL request and authentication will be handled by the client!

# Verifying users in the API backend
Now imagine a user wants to access a protected field of our api (see [here](https://dev.to/peteole/how-we-built-a-student-project-platform-using-graphql-react-golang-ory-kratos-and-kubernetes-part-1-19jg) for a post about our API architecture) and the backend needs to decide somehow who the requester is in order to know if they have the permission to access the field. On a high level, the backend must extract the session cookie from the request and ask kratos who that cookie belongs to. This is done by injecting some code at the root of our server with the [kratos go sdk](https://www.ory.sh/docs/kratos/sdk). The go specific part of the sdk is not documented at all as far as I know so we had to fiddle around with it until it worked.

For every request,we attach the user ID of the requester to the context. But to find out the user ID, we extract the session cookie from the request and check it against kratos with the `ToSession` function. Note that we [only set the cookie for that request and not some header](https://github.com/ory/kratos/discussions/2053#discussioncomment-1798113)!
```go
package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/99designs/gqlgen/graphql"
	"github.com/99designs/gqlgen/graphql/handler"
	"github.com/99designs/gqlgen/graphql/playground"
	kc "github.com/ory/kratos-client-go"
	"github.com/rs/cors"
	"gitlab.lrz.de/projecthub/gql-api/auth"
	"gitlab.lrz.de/projecthub/gql-api/graph/generated"
	"gitlab.lrz.de/projecthub/gql-api/graph/resolvers"
)

const port = "8080"

func main() {
	kratosConfig := kc.NewConfiguration()
	kratosConfig.Host = "kratos-public"
	kratosConfig.Scheme = "http"
	api := kc.NewAPIClient(kratosConfig)
	resolver, _ := resolvers.NewResolver(os.ExpandEnv(os.Getenv("DB_CONNECTION_STRING")))

	config := generated.Config{Resolvers: resolver}
	config.Directives.IsLoggedIn = func(ctx context.Context, obj interface{}, next graphql.Resolver) (res interface{}, err error) {
		if _, loginErr := auth.IdentityFromContext(ctx); loginErr == nil {
			return next(ctx)
		} else {
			return nil, fmt.Errorf("authenticate please")
		}
	}
	srv := handler.NewDefaultServer(generated.NewExecutableSchema(config))

	http.Handle("/api", playground.Handler("GraphQL playground", "/api/query"))
	corsHandler := cors.New(cors.Options{AllowedOrigins: []string{"http://localhost:3000","https://huddle-groups.readme.io"}, AllowCredentials: true, OptionsPassthrough: true, AllowedHeaders: []string{"*"}}).Handler(srv)
	http.HandleFunc("/api/query", func(rw http.ResponseWriter, r *http.Request) {
		cookie, err := r.Cookie("ory_kratos_session")
		if err != nil {
			corsHandler.ServeHTTP(rw, r)
			return
		}
		toSessionReq := api.V0alpha2Api.ToSession(context.Background()).Cookie(cookie.String())
		session, _, err := toSessionReq.Execute()
		if err != nil {
			corsHandler.ServeHTTP(rw, r)
			return
		}

		newContext := auth.NewIdentityContext(r.Context(), &session.Identity)
		newRequest := r.WithContext(newContext)
		corsHandler.ServeHTTP(rw, newRequest)
	})

	log.Printf("connect to http://localhost:%s/ for GraphQL playground", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}
```
We create a GraphQL directive to annotate that a user must be logged in to access a field here, too. Like this we can annotate a field with `@isLoggedIn` in our schema and if the user is not, an error "authenticate please" will be returned, asking the user to log in in the UI as described above.

We wrapped the code to write or read the identity to/from the context in the `auth` package:
```go
package auth

import (
	"context"
	"fmt"

	kc "github.com/ory/kratos-client-go"
)

type Identity struct {
	kc.Identity
	traits map[string]interface{}
}
type customKey int

var identityKey customKey

func NewIdentityContext(ctx context.Context, identity *kc.Identity) context.Context {
	return context.WithValue(ctx, identityKey, identity)
}
func IdentityFromContext(ctx context.Context) (*Identity, error) {
	identity, ok := ctx.Value(identityKey).(*kc.Identity)
	if ok {
		traits, ok := identity.Traits.(map[string]interface{})
		if ok {
			return &Identity{Identity: *identity, traits: traits}, nil
		}
	}
	return nil, fmt.Errorf("no identity found in context")
}

func (i *Identity) GetTrait(key string) (string, bool) {
	val, ok := i.traits[key].(string)
	return val, ok
}
```
The traits property of the sdk's identity type is untyped since it depends on the identity schema, so in our own identity type we wrapped it in a map with a custom getter for string fields.

In a resolver, we can access the identity like this:

```go
func (r *mutationResolver) SetMyDescription(ctx context.Context, description string) (bool, error) {
	me, err := auth.IdentityFromContext(ctx)
	if err != nil {
		return false, err
	}
	err = r.queries.SetDescription(context.Background(), sqlc.SetDescriptionParams{Description: description, ID: uuid.MustParse(me.Id)})
	return err == nil, err
}
```
Pretty elegant, right?

I hope to have given a nice introduction to Ory Kratos!
Please feel free to comment on what we could do more elegantly! Also I'm interested in your solutions for secret management in Kubernetes!
