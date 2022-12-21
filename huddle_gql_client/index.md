After [explaining how we built our student project graphql API in a typesafe way](https://dev.to/peteole/how-we-built-a-student-project-platform-using-graphql-react-golang-ory-kratos-and-kubernetes-part-1-19jg), we will continue by having a look at the client side.

In terms of technology we use React (typescript) with the [Apollo GraphQL Client](https://www.apollographql.com/docs/react/) as well as a code generator for type safety.

## Apollo client

The Apollo client has some serious advantages:

- The whole application state is kept in an advanced cache which requires only minimal configuration. This minimizes network traffic and keeps the UI elements in sync.
- Nice integration with React
- Well customizable

This is the basic usage:

```tsx
// main.tsx
import App from './App'
import {
  ApolloProvider,
  ApolloClient
} from "@apollo/client";
export const client = new ApolloClient({
    uri: 'https://huddle.hsg.fs.tum.de/api/query',
    cache: new InMemoryCache(),
});
ReactDOM.render(
  <React.StrictMode>
    <ApolloProvider client={client}> //inject the client here
        <App/>
    </ApolloProvider>
  </React.StrictMode>,
  document.getElementById('root')
)
```
```tsx
// App.tsx
import { gql, useQuery } from '@apollo/client';
const App: React.FC = () => {
    const [projectId, setProjectId]=useState("")
    const {data} = useQuery(gql`
        query($id: ID!){
            getProject(id: $id) {
                name
                description
            }            
        }
    `,{variables:{id:projectId}}
    )
    return (
        <div>
            Enter project ID to explore
            <input onChange={(newId)=>{
                setProjectId(newId)
            }}>
            <div>
                <p>Project name: {data.getProject.name}</p>
                <p>Project description: {data.getProject.description}</p>
            </div>
        </div>
    )
}
export default App
```
This little code will allow you to explore huddle projects!

## Introduce typesafety

The code above already looks nice, but the data returned and the variables used in the `useQuery` are untyped. To fix this issue we will introduce yet another code generator:

With [GraphQL Code Generator](https://www.graphql-code-generator.com/) you define the queries in a document and let the code generator generate typesafe versions of the `useQuery` apollo hook (using the GraphQL schema of your API).

The setup is simple:

```bash
yarn add graphql
yarn add @graphql-codegen/cli
yarn graphql-codegen init
yarn install # install the choose plugins
yarn add @graphql-codegen/typescript-react-query
yarn add @graphql-codegen/typescript
yarn add @graphql-codegen/typescript-operations
```
Now let's configure the code generator by editing the newly created file `codegen.yml`:
```yaml
overwrite: true
schema: https://huddle.hsg.fs.tum.de/api/query # link your API schema here
documents: operations/* #define graphql queries you want to use react here
generates:
  src/schemas.ts: #the generated code will end up here
    plugins:
      - "typescript"
      - "typescript-operations"
      - "typescript-react-apollo"
      - typescript-apollo-client-helpers
```
You can now add operations you want to use in your components in `operations/projectOperations.gql`:
```graphql
query getProjectById($id: ID!) {
  getProject(id: $id) {
    id
    name
    description
    creator {
      username
      id
    }
    location {
      name
    }
    saved
    tags
...
  }
}
```
Installing the [GraphQL VSCode extension](https://marketplace.visualstudio.com/items?itemName=GraphQL.vscode-graphql) and creating the `graphql.config.yml` file with the following content
```yaml
schema:
  - https://huddle.hsg.fs.tum.de/api/query
documents: ./operations/*.graphqls
```
will even give you intellisense in the operations
![Gql intellisense](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/1cvg3o462gm6lpa8rrc6.png)
 
Executing `yarn run graphql-codegen` will do all the magic for you!
Let's say we want to implement the `ProjectDetail`-component which displays details of the project with the id passed in the props. We can now import the `useGetProjectByIdQuery` hook!

```tsx
import { useGetProjectByIdQuery, ...} from '../schemas';
import { ImageGallery } from '../shared/ImageGallery';
import ReactMarkdown from 'react-markdown';
...
export type ProjectDetailProps = {
    id: string
    onBackClicked?: () => void
}
const ProjectDetail: React.FC<ProjectDetailProps> = (props) => {
    const projectResult = useGetProjectByIdQuery({ variables: { id: props.id } });
 ...
    if (props.id == "") return <div></div>
    if (projectResult.loading) return <div className='project-detail'>Loading...</div>
    if (projectResult.error) return <div className='project-detail'>Error: {projectResult.error.message}</div>
    const images = projectResult.data?.getProject?.images
    return (
        <div className="project-detail">
...
            <h1>{projectResult.data?.getProject?.name}</h1>
...
            <ReactMarkdown >{projectResult.data?.getProject?.description || "(no description provided)"}</ReactMarkdown>
            {images && images.length > 0 ? <div >
                <ImageGallery images={images.map(image => ({
                    url: image.url,
                    description: image.description || undefined
                }))} />
            </div> : null}
            <p>Created by {projectResult.data?.getProject?.creator.username}</p>
...
        </div>
    );
}

export default ProjectDetail;
```
Note that this hook is fully typed:
![Typed Hook](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/2kcmzab0smk1ocafu5n4.png)
Nice! It's this easy to make an API end-to-end typesafe!

Now as a bonus let's have a look at how to customize the cache to our needs.
Let's say we update a project at some place in the code. We want Apollo to sync the update to all the components we used in the code. To do so, we need to tell Apollo somehow to decide which `Project` objects correspond to the same object (and must therefore be updated) and how to apply updates to the cache for instance if only a few fields are refetched with a new value. This is done by passing a `TypePolicies` object to the Apollo client cache. The type of this object is also generated by our code generator. So let's do it:

```tsx
// main.tsx
import App from './App'
import { StrictTypedTypePolicies } from "./schemas";
import { offsetLimitPagination } from "@apollo/client/utilities";
import {
  ApolloProvider,
  ApolloClient
} from "@apollo/client";
const typePolicies: StrictTypedTypePolicies={
    Project:{
        keyFields:["id"], // treat Project objects with the same id as the same project
        merge(existing, incoming) { //merge new projects on old projects. This may be more advanced.
            return { ...existing, ...incoming };
        }
    },
     Query:{
        fields:{
            searchProjects: offsetLimitPagination()
        }
    }
}
export const client = new ApolloClient({
    uri: 'https://huddle.hsg.fs.tum.de/api/query',
    cache: new InMemoryCache({typePolicies}),
});
ReactDOM.render(
  <React.StrictMode>
    <ApolloProvider client={client}> //inject the client here
        <App/>
    </ApolloProvider>
  </React.StrictMode>,
  document.getElementById('root')
)
```

The custom merge function can also be used to concatenate parts of an infinite feed of results to one list. Since the query uses "offset" and "limit" as parameters, we can use the existing merger function `offsetLimitPagination` provided by Apollo, which merges results by concatenating the result lists according to the offset and limit parameters. 
Like this you can trigger a fetching of more results and append them to current result list flawlessly when the user scrolls towards the end of the list.

For instance we have a `searchProject` function which receives an offset and a limit of results. This is how we implement an infinite scroll bar:
```tsx
//HomePage.tsx
import { useRef, useState } from 'react';
import HomeHeader from '../home-header/home-header';
import ProjectList from '../project-list/project-list';
import { useSearchProjectsQuery } from '../schemas';
import "./home-page.css"

function HomePage() {
    const [searchString, setSearchString] = useState("");
...
    const projectData = useSearchProjectsQuery({ variables: { searchString: searchString, limit: 10, options: getOptions(category) } })
    const lastRefetchOffset = useRef(-1)// keep track of the last offset we refetched to see if currently new data is loading already
    const onScrollToBottom = () => {
        if (lastRefetchOffset.current === projectData.data?.searchProjects?.length) {
            return;// already loading, so do nothing
        }
        lastRefetchOffset.current = projectData.data?.searchProjects?.length || -1;
        projectData.fetchMore({
            variables: {
                offset: projectData.data?.searchProjects?.length,
                limit: 10,
                options: getOptions(category),
                searchString: searchString
            }
        })
    }
    const entries = projectData.data?.searchProjects.map(p => ({
        description: p.description,
        id: p.id,
        name: p.name,
        ...)) || []
    return (
        <div style={{ position: "relative" }}>
            <HomeHeader onSearchStringChange={(searchString: string) => {
                setSearchString(searchString) // HomeHeader contains a search bar whose updates we can subscribe to here
            }} .../>
            <div className='home-bottom'>
                <ProjectList entries={entries} onScrollToBottom={onScrollToBottom} />
            </div>
        </div>
    );
}

export default HomePage;
```

I hope you liked this collection of useful tips for using GraphQL on the client side. Feel free to comment!

Stay tuned for the [next part](https://dev.to/peteole/how-we-built-a-student-project-platform-using-graphql-react-golang-ory-kratos-and-kubernetes-part-3-authentication-2603) where I will discuss how we handele authentication with Ory Kratos!
