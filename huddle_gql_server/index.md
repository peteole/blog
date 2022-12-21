## The idea
I started my studies at university in times of Covid. With limited contact to other students, but lots of ideas for side projects, I often dreamed of a platform to share such project ideas on and check out what existing student projects do (it turned out there are actually pretty many of them who do really cool stuff but nobody knows about).
This is how it looks like:
![Our platform in practice](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/kmwr5805aoda9muekov9.png)
If you want just check out [our current prototype](huddle.hsg.fs.tum.de).
 
## Our architecture
For scalability and easy deployment (and also just because we can) we decided to deploy all our code in a Kubernetes cluster. For development we do only need little resources, so we just rented a 3-Dollar-a-month VM with a public IP and installed [k3s](https://k3s.io/) on it.

We exchange most data using a Graphql API that is served by a [Golang-Application](https://gitlab.lrz.de/projecthub/gql-api). We use a schema-first-approach, i.e. the source of truth for what our API can do is a graphql schema. From that schema, we generate both typesafe client- and server code.
Authentication is handled by [ory kratos](ory.sh/kratos).

The UI is built with React and Apollo Client.

As a database, we use an in-cluster postgresql instance.

###  The API
First of all, you can play around with our API [here](huddle.hsg.fs.tum.de/api) and find the code [here](gitlab.lrz.de/projecthub/gql-api)
Our API is built with [gqlgen](gqlgen.com). The folder structure looks as follows:
```
...
├── go.mod
├── go.sum
├── gqlgen.yml # config for auto-generating go-code from gql-schema
├── graph
│   ├── generated
│   │   └── generated.go
│   ├── model # partly auto-generated, partly manually edited representations of the graphql datastructures
│   │   ├── models_gen.go
│   │   └── user.go
...
│   ├── resolvers # The code that actually handles graphql requests,  method heads are auto-generated from schema
│   │   └── user.resolvers.go
...
│   └── schema
│       └── user.graphqls
...
├── server.go # entrypoint
├── sqlc # generated database query code
│   └── users.sql.go
...
├── sqlc.yaml # config for autogenerating go-code for sql queries
├── sql-queries # queries we want go-code for
│   └── users.sql
...
└── tools.go
```
You can initialize most of this project structure quickly by following [this](gqlgen.com) comprehensive guide.

Now implementing new features for our API is a joy! The workflow is the following:
1. Add the new feature to our graphql schema. Say for instance we want to enable our API to add numbers. We create a file called `adder.graphqls` (in the schemas folder) with the following content:
```graphql
extend type Query{
    addNumber(a:Int!,b:Int!):Int!
}
```
2. Run the codegen comand:
```
go run github.com/99designs/gqlgen generate
```
A new file  `graph/resolvers/adder.resolver.go` will be created with the following content:
```go
package resolvers

// This file will be automatically regenerated based on the schema, any resolver implementations
// will be copied through when generating and any unknown code will be moved to the end.

import (
	"context"
	"fmt"

	"gitlab.lrz.de/projecthub/gql-api/graph/generated"
)

func (r *queryResolver) AddNumber(ctx context.Context, a int, b int) (*int, error) {
	panic(fmt.Errorf("not implemented"))
}

// Query returns generated.QueryResolver implementation.
func (r *Resolver) Query() generated.QueryResolver { return &queryResolver{r} }

type queryResolver struct{ *Resolver }
```
3. All we have to do now is implement the method:

```go
package resolvers

// This file will be automatically regenerated based on the schema, any resolver implementations
// will be copied through when generating and any unknown code will be moved to the end.

import (
	"context"
	"fmt"

	"gitlab.lrz.de/projecthub/gql-api/graph/generated"
)

func (r *queryResolver) AddNumber(ctx context.Context, a int, b int) (int, error) {
	return a+b,nil
}

// Query returns generated.QueryResolver implementation.
func (r *Resolver) Query() generated.QueryResolver { return &queryResolver{r} }

type queryResolver struct{ *Resolver }
```
See how we get perfectly typesafe code here!

With this little setup, we are able to run our server and get [documentation](huddle.hsg.fs.tum.de/api) for free!

Now let's look at how we actually serve useful data with database queries. Take for instance our API for getting a project by its ID:
```graphql
# project.graphqls

type Project {
  id: ID!
  name: String!
  description: String!
  languages: [String!]!
  location: Location
  participants: [User!]!
  creator: User!
  images: [Image!]!
  createdAt: Time
  # if the current user saved this project
  saved: Boolean!
  tags: [String!]!
}

extend type Query {
  getProject(id: ID!): Project
}
```
The generated go function head looks like this:
```go
func (r *queryResolver) GetProject(ctx context.Context, id string) (*model.Project, error)
```
Now we created an SQL query in the file `sql-queries/projects.sql`:
```sql
-- name: GetProjectByID :one
SELECT *
FROM projects
WHERE id = $1;
```
We now use [sqlc](https://sqlc.dev/) to generate typesafe go code for this query. To do so, we need the current database schema, so we created a nice little script that port-forwards our database from the cluster, dumps out the schema and invokes sqlc:
```
export POSTGRES_PASSWORD=$(kubectl get secret --namespace default psql-postgresql -o jsonpath="{.data.postgresql-password}" | base64 --decode)
kubectl port-forward --namespace default svc/psql-postgres 5432:5432 &
sleep 2
PGPASSWORD="$POSTGRES_PASSWORD" pg_dump --host 127.0.0.1 -U postgres -d postgres -p 5432 -s > schema.sql
rm -Rf sqlc
sqlc generate
kill $(jobs -p)
```
sqlc is configured to output the queries in the `sqlc`-subfolder:
```yaml
# sqlc.yaml
version: "1"
packages:
  - path: "sqlc"
    name: "sqlc"
    engine: "postgresql"
    schema: "schema.sql"
    queries: "sql-queries"
```
So now we can inject the database code into our resolver:
```go
// resolvers/resolver.go
package resolvers

import (
	"database/sql"

	"gitlab.lrz.de/projecthub/gql-api/sqlc"

)

// It serves as dependency injection for your app, add any dependencies you require here.

type Resolver struct {
	queries *sqlc.Queries
}

func NewResolver(connstring string) (*Resolver, error) {
	db, err := sql.Open("postgres", connstring)
	if err != nil {
		return nil, err
	}
	queries := sqlc.New(db)
	return &Resolver{
		queries: queries,
	}, nil
}
```

This allows us to make database queries in every resolver function, so let's apply this to our project-by-id-resolver:

```go
func (r *queryResolver) GetProject(ctx context.Context, id string) (*model.Project, error) {
	dbProject, err := r.queries.GetProjectByID(context.Background(), uuid.MustParse(id))
	if err != nil {
		return nil, err
	}
// now just transform the db result to our gql project datatype
	return 	return &Project{
		ID:          dbProject.ID.String(),
		Name:        dbProject.Name,
		Description: dbProject.Description,
		CreatorID:   dbProject.Creator.String(),
		Languages:   []string{},
	}, nil
}
```
Here the auto-generated datatype of the project returned by the db query looks pretty friendly:
```go
package sqlc
type Project struct {
	ID          uuid.UUID
	Name        string
	Description string
	CreatedAt   sql.NullTime
	Creator     uuid.UUID
	Location    sql.NullString
}
```
Yay!

In the [next part](https://dev.to/peteole/how-we-built-a-student-project-platform-using-graphql-react-golang-ory-kratos-and-kubernetes-part-2-2lnh), I will discuss how we use our API on our React UI in a typesafe way.

Feel free to comment, ask for details and stay tuned!
