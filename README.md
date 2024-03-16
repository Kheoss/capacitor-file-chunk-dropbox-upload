# capacitor-file-chunk-reader

A capacitor plugin for Android and IOS to read BIG files in chunks

## Install

```bash
npm install capacitor-file-chunk-reader
npx cap sync
```

## API

<docgen-index>

* [`readChunk(...)`](#readchunk)
* [`uploadFileChunk(...)`](#uploadfilechunk)
* [`uploadFile(...)`](#uploadfile)

</docgen-index>

<docgen-api>
<!--Update the source file JSDoc comments and rerun docgen to update the docs below-->

### readChunk(...)

```typescript
readChunk(options: { uri: string; offset: number; length: number; }) => Promise<{ data: string; }>
```

| Param         | Type                                                          |
| ------------- | ------------------------------------------------------------- |
| **`options`** | <code>{ uri: string; offset: number; length: number; }</code> |

**Returns:** <code>Promise&lt;{ data: string; }&gt;</code>

--------------------


### uploadFileChunk(...)

```typescript
uploadFileChunk(options: { uri: string; accessToken: string; targetPath: string; fileSize: number; }) => void
```

| Param         | Type                                                                                     |
| ------------- | ---------------------------------------------------------------------------------------- |
| **`options`** | <code>{ uri: string; accessToken: string; targetPath: string; fileSize: number; }</code> |

--------------------


### uploadFile(...)

```typescript
uploadFile(options: { uri: string; accessToken: string; targetPath: string; }) => void
```

| Param         | Type                                                                   |
| ------------- | ---------------------------------------------------------------------- |
| **`options`** | <code>{ uri: string; accessToken: string; targetPath: string; }</code> |

--------------------

</docgen-api>
