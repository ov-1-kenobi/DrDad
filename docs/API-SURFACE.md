# API surface (generated - do not edit)

Exact public signatures read from the compiled assemblies. Regenerated on every build,
so it cannot drift from the code. **Search this before writing a call you are unsure of** -
it is faster than grepping source and it is the only copy that includes NuGet packages.

## This solution

### local-tools

`class ApiSurface`   (in local-tools\ApiSurface.cs)
  - `string Generate(string projectDir, string outFile = ...)`

`class Chunk`   (in local-tools\Rag.cs)
  - `Chunk()`
  - `Nullable<int> Page { get; set; }`
  - `string Source { get; set; }`
  - `string Text { get; set; }`
  - `float[] Vector { get; set; }`

`class HybridTools`   (in local-tools\HybridTools.cs)
  - `HybridTools()`
  - `Task<string> LocalGenerate(string prompt, string system = ...)`

`class Rag`   (in local-tools\Rag.cs)
  - `string DescribeCorpus()`
  - `Task<string> DescribeImageAsync(string path, string prompt)`
  - `Task<string> IndexAsync()`
  - `Task<string> IngestUrlAsync(string url)`
  - `string ListDocs()`
  - `Task<string> LocalGenerateAsync(string prompt, string system)`
  - `Task<string> SearchAsync(string query, int k)`
  - `Task<string> WebSearchAsync(string query, int k)`
  - `bool HybridEnabled { get; }`

`class Sensors`   (in local-tools\Sensors.cs)
  - `Task<string> DetectAsync(string imagePath, float minConfidence, float iouThreshold)`
  - `Task<string> TranscribeAsync(string audioPath)`

`class Tools`   (in local-tools\Tools.cs)
  - `Tools()`
  - `Task<string> DescribeImage(string path, string prompt = ...)`
  - `Task<string> DetectObjects(string path, float minConfidence = ..., float iouThreshold = ...)`
  - `Task<string> IndexDatasheets()`
  - `Task<string> IngestUrl(string url)`
  - `string ListDatasheets()`
  - `Task<string> SearchDatasheets(string query, int k = ...)`
  - `Task<string> TranscribeAudio(string path)`
  - `Task<string> WebSearch(string query, int k = ...)`

## Referenced packages

### AngleSharp

`enum Accessors`
  - `values: None, Getter, Setter, Deleter, Adder, Remover, Method`

`class DomAccessorAttribute`
  - `DomAccessorAttribute(Accessors type)`
  - `Accessors Type { get; }`

`class DomConstructorAttribute`
  - `DomConstructorAttribute()`

`class DomDescriptionAttribute`
  - `DomDescriptionAttribute(string description)`
  - `string Description { get; }`

`class DomExposedAttribute`
  - `DomExposedAttribute(string target)`
  - `string Target { get; }`

`class DomHistoricalAttribute`
  - `DomHistoricalAttribute()`

`class DomInitDictAttribute`
  - `DomInitDictAttribute(int offset = ..., bool optional = ...)`
  - `bool IsOptional { get; }`
  - `int Offset { get; }`

`class DomInstanceAttribute`
  - `DomInstanceAttribute(string name)`
  - `string Name { get; }`

`class DomLenientThisAttribute`
  - `DomLenientThisAttribute()`

`class DomLiteralsAttribute`
  - `DomLiteralsAttribute()`

`class DomNameAttribute`
  - `DomNameAttribute(string officialName)`
  - `string OfficialName { get; }`

`class DomNoInterfaceObjectAttribute`
  - `DomNoInterfaceObjectAttribute()`

`class DomPutForwardsAttribute`
  - `DomPutForwardsAttribute(string propertyName)`
  - `string PropertyName { get; }`

`enum CacheStatus`
  - `values: Uncached, Idle, Checking, Downloading, UpdateReady, Obsolete`

`class InteractivityEvent<T>`
  - `InteractivityEvent`1(string eventName, T data)`
  - `void SetResult(Task value)`
  - `T Data { get; }`
  - `Task Result { get; }`

`class TrackEvent`
  - `TrackEvent(string eventName, Exception error)`
  - `Exception Error { get; }`

`interface IApplicationCache`
  - `void Abort()`
  - `void Swap()`
  - `void Update()`
  - `CacheStatus Status { get; }`

`interface IHistory`
  - `void Back()`
  - `void Forward()`
  - `void Go(int delta = ...)`
  - `void PushState(object data, string title, string url = ...)`
  - `void ReplaceState(object data, string title, string url = ...)`
  - `int Index { get; }`
  - `IDocument Item { get; }`
  - `int Length { get; }`
  - `object State { get; }`

`interface INavigatorContentUtilities`
  - `bool IsContentHandlerRegistered(string mimeType, string url)`
  - `bool IsProtocolHandlerRegistered(string scheme, string url)`
  - `void RegisterContentHandler(string mimeType, string url, string title)`
  - `void RegisterProtocolHandler(string scheme, string url, string title)`
  - `void UnregisterContentHandler(string mimeType, string url)`
  - `void UnregisterProtocolHandler(string scheme, string url)`

`interface INavigatorId`
  - `string Name { get; }`
  - `string Platform { get; }`
  - `string UserAgent { get; }`
  - `string Version { get; }`

`interface INavigatorOnline`
  - `bool IsOnline { get; }`

`interface INavigatorStorageUtilities`
  - `void WaitForStorageUpdates()`

`class EncodingMetaHandler`
  - `EncodingMetaHandler()`

`class EventLoopExtensions`
  - `void Enqueue(IEventLoop loop, Action action, TaskPriority priority = ...)`
  - `Task<T> EnqueueAsync<T>(IEventLoop loop, Func<CancellationToken, T> action, TaskPriority priority = ...)`

`interface ICommand`
  - `bool Execute(IDocument document, bool showUserInterface, string value)`
  - `string GetValue(IDocument document)`
  - `bool IsEnabled(IDocument document)`
  - `bool IsExecuted(IDocument document)`
  - `bool IsIndeterminate(IDocument document)`
  - `bool IsSupported(IDocument document)`
  - `string CommandId { get; }`

`interface ICommandProvider`
  - `ICommand GetCommand(string name)`

`interface IEncodingProvider`
  - `Encoding Suggest(string locale)`

`interface IEventLoop`
  - `void CancelAll()`
  - `ICancellable Enqueue(Action<CancellationToken> action, TaskPriority priority)`
  - `void Spin()`

`interface IMetaHandler`
  - `void HandleContent(IHtmlMetaElement element)`

`interface INavigationHandler`
  - `Task<IDocument> NavigateAsync(DocumentRequest request, CancellationToken token)`
  - `bool SupportsProtocol(string protocol)`

`interface ISpellCheckService`
  - `void Ignore(string word, bool persistent)`
  - `bool IsCorrect(string word)`
  - `IEnumerable<string> SuggestFor(string word)`
  - `CultureInfo Culture { get; }`

`class LocaleEncodingProvider`
  - `LocaleEncodingProvider()`
  - `Encoding Suggest(string locale)`

`class RefreshMetaHandler`
  - `RefreshMetaHandler(Predicate<Url> shouldRefresh = ...)`

`enum Sandboxes`
  - `values: None, Navigation, AuxiliaryNavigation, TopLevelNavigation, Plugins, Origin, Forms, PointerLock, Scripts, AutomaticFeatures, Fullscreen, DocumentDomain, Presentation`

`enum TaskPriority`
  - `values: None, Normal, Microtask, Critical`

`class BrowsingContext`
  - `BrowsingContext(IConfiguration configuration = ...)`
  - `IBrowsingContext CreateChild(string name, Sandboxes security)`
  - `IBrowsingContext FindChild(string name)`
  - `T GetService<T>()`
  - `IEnumerable<T> GetServices<T>()`
  - `IBrowsingContext New(IConfiguration configuration = ...)`
  - `IBrowsingContext NewFrom<TService>(TService instance)`
  - `IDocument Active { get; set; }`
  - `IDocument Creator { get; }`
  - `IWindow Current { get; }`
  - `IEnumerable<object> OriginalServices { get; }`
  - `IBrowsingContext Parent { get; }`
  - `Sandboxes Security { get; }`
  - `IHistory SessionHistory { get; }`

`class BrowsingContextExtensions`
  - `IBrowsingContext CreateChildFor(IBrowsingContext context, string target)`
  - `IBrowsingContext FindChildFor(IBrowsingContext context, string target)`
  - `ICommand GetCommand(IBrowsingContext context, string commandId)`
  - `string GetCookie(IBrowsingContext context, Url url)`
  - `IStylingService GetCssStyling(IBrowsingContext context)`
  - `CultureInfo GetCulture(IBrowsingContext context)`
  - `CultureInfo GetCultureFrom(IBrowsingContext context, string language)`
  - `Encoding GetDefaultEncoding(IBrowsingContext context)`
  - `IEnumerable<Task> GetDownloads<T>(IBrowsingContext context)`
  - `TFactory GetFactory<TFactory>(IBrowsingContext context)`
  - `IScriptingService GetJsScripting(IBrowsingContext context)`
  - `string GetLanguage(IBrowsingContext context)`
  - `INavigationHandler GetNavigationHandler(IBrowsingContext context, Url url)`
  - `TProvider GetProvider<TProvider>(IBrowsingContext context)`
  - `IResourceService<TResource> GetResourceService<TResource>(IBrowsingContext context, string type)`
  - `IScriptingService GetScripting(IBrowsingContext context, string type)`
  - `ISpellCheckService GetSpellCheck(IBrowsingContext context, string language)`
  - `IStylingService GetStyling(IBrowsingContext context, string type)`
  - `Task InteractAsync<T>(IBrowsingContext context, string eventName, T data)`
  - `bool IsScripting(IBrowsingContext context)`
  - `void NavigateTo(IBrowsingContext context, IDocument document)`
  - `Task<IDocument> OpenAsync(IBrowsingContext context, IResponse response, CancellationToken cancel = ...)`
  - `Task<IDocument> OpenAsync(IBrowsingContext context, DocumentRequest request, CancellationToken cancel = ...)`
  - `Task<IDocument> OpenAsync(IBrowsingContext context, Url url, CancellationToken cancel = ...)`
  - `Task<IDocument> OpenAsync(IBrowsingContext context, Action<VirtualResponse> request, CancellationToken cancel = ...)`
  - `Task<IDocument> OpenAsync(IBrowsingContext context, string address, CancellationToken cancellation = ...)`
  - `Task<IDocument> OpenNewAsync(IBrowsingContext context, string url = ..., CancellationToken cancellation = ...)`
  - `IBrowsingContext ResolveTargetContext(IBrowsingContext context, string target)`
  - `void SetCookie(IBrowsingContext context, Url url, string value)`
  - `void TrackError(IBrowsingContext context, Exception ex)`

`class BaseTokenizer`
  - `BaseTokenizer(TextSource source)`
  - `void Dispose()`
  - `string FlushBuffer()`
  - `TextPosition GetCurrentPosition()`
  - `bool DisableElementPositionTracking { get; set; }`
  - `int InsertionPoint { get; set; }`
  - `int Position { get; }`

`interface IBindable`
  - `void Update(string value)`

`interface ICancellable`
  - `void Cancel()`
  - `bool IsCompleted { get; }`
  - `bool IsRunning { get; }`

`interface ICancellable<T>`
  - `Task<T> Task { get; }`

`interface ICharBuffer`
  - `Nullable<ReadOnlyMemory<char>> TryCopyTo(char[] buffer)`
  - `char Item { get; }`
  - `int Length { get; }`

`class ObjectExtensions`
  - `IEnumerable<T> Concat<T>(IEnumerable<T> items, T element)`
  - `double Constraint(double value, double min, double max)`
  - `IEnumerable<T> Except<T>(IEnumerable<T> items, T element)`
  - `T GetItemByIndex<T>(IEnumerable<T> items, int index)`
  - `string GetMessage<T>(T code)`
  - `U GetOrDefault<T, U>(IDictionary<T, U> values, T key, U defaultValue)`
  - `Dictionary<string, string> ToDictionary(object values)`
  - `Nullable<T> TryGet<T>(IDictionary<string, object> values, string key)`
  - `object TryGet(IDictionary<string, object> values, string key)`

`struct StringOrMemory`
  - `StringOrMemory(string str)`
  - `StringOrMemory(ReadOnlyMemory<char> memory)`
  - `bool Equals(StringOrMemory other)`
  - `bool Equals(object obj)`
  - `int GetHashCode()`
  - `StringOrMemory Replace(char target, char replacement)`
  - `string ToString()`
  - `StringOrMemory Empty { get; }`
  - `bool IsNullOrEmpty { get; }`
  - `char Item { get; }`
  - `int Length { get; }`
  - `ReadOnlyMemory<char> Memory { get; }`

`class Configuration`
  - `Configuration(IEnumerable<object> services = ...)`
  - `IConfiguration Default { get; }`
  - `IEnumerable<object> Services { get; }`

`class ConfigurationExtensions`
  - `bool Has<TService>(IConfiguration configuration)`
  - `IConfiguration With(IConfiguration configuration, object service)`
  - `IConfiguration With(IConfiguration configuration, IEnumerable<object> services)`
  - `IConfiguration With<TService>(IConfiguration configuration, Func<IBrowsingContext, TService> creator)`
  - `IConfiguration WithCulture(IConfiguration configuration, string name)`
  - `IConfiguration WithCulture(IConfiguration configuration, CultureInfo culture)`
  - `IConfiguration WithDefaultCookies(IConfiguration configuration)`
  - `IConfiguration WithDefaultLoader(IConfiguration configuration, LoaderOptions setup = ...)`
  - `IConfiguration WithLocaleBasedEncoding(IConfiguration configuration)`
  - `IConfiguration WithMetaRefresh(IConfiguration configuration, Predicate<Url> shouldRefresh = ...)`
  - `IConfiguration WithOnly<TService>(IConfiguration configuration, TService service)`
  - `IConfiguration WithOnly<TService>(IConfiguration configuration, Func<IBrowsingContext, TService> creator)`
  - `IConfiguration Without(IConfiguration configuration, object service)`
  - `IConfiguration Without(IConfiguration configuration, IEnumerable<object> services)`
  - `IConfiguration Without<TService>(IConfiguration configuration)`

`class CssStyleFormatter`
  - `CssStyleFormatter()`

`class CssUtilities`
  - `string Escape(string text)`

`class DefaultAttributeSelectorFactory`
  - `DefaultAttributeSelectorFactory()`
  - `ISelector Create(string combinator, string name, string value, string prefix, bool insensitive)`
  - `void Register(string combinator, Creator creator)`
  - `Creator Unregister(string combinator)`

`class DefaultPseudoClassSelectorFactory`
  - `DefaultPseudoClassSelectorFactory()`
  - `ISelector Create(string name)`
  - `void Register(string name, ISelector selector)`
  - `ISelector Unregister(string name)`

`class DefaultPseudoElementSelectorFactory`
  - `DefaultPseudoElementSelectorFactory()`
  - `ISelector Create(string name)`
  - `void Register(string name, ISelector selector)`
  - `ISelector Unregister(string name)`

`interface ICssMedium`
  - `string Constraints { get; }`
  - `IEnumerable<IMediaFeature> Features { get; }`
  - `bool IsExclusive { get; }`
  - `bool IsInverse { get; }`
  - `string Type { get; }`

`interface IMediaFeature`
  - `bool HasValue { get; }`
  - `bool IsMaximum { get; }`
  - `bool IsMinimum { get; }`
  - `string Name { get; }`
  - `string Value { get; }`

`interface IMediaList`
  - `void Add(string medium)`
  - `void Remove(string medium)`
  - `string Item { get; }`
  - `int Length { get; }`
  - `string MediaText { get; set; }`

`interface IMultiSelector`
  - `ISelector GetMatchingSelector(IElement element, IElement scope = ...)`

`interface INestedSelector`
  - `ISelector ParentSelector { get; set; }`

`interface ISelector`
  - `void Accept(ISelectorVisitor visitor)`
  - `bool Match(IElement element, IElement scope)`
  - `Priority Specificity { get; }`
  - `string Text { get; }`

`class SelectorExtensions`
  - `bool Match(ISelector selector, IElement element)`
  - `IHtmlCollection<IElement> MatchAll(ISelector selector, IEnumerable<IElement> elements, IElement scope)`
  - `IElement MatchAny(ISelector selector, IEnumerable<IElement> elements, IElement scope)`

`class StyleExtensions`
  - `IStringList CreateStyleSheetSets(INode parent)`
  - `IStyleSheetList CreateStyleSheets(INode parent)`
  - `void EnableStyleSheetSet(IStyleSheetList sheets, string name)`
  - `IEnumerable<string> GetAllStyleSheetSets(IStyleSheetList sheets)`
  - `IEnumerable<string> GetEnabledStyleSheetSets(IStyleSheetList sheets)`
  - `IEnumerable<IStyleSheet> GetStyleSheets(INode parent)`
  - `string LocateNamespace(IStyleSheetList sheets, string prefix)`

`interface IAttributeSelectorFactory`
  - `ISelector Create(string combinator, string name, string value, string prefix, bool insensitive)`

`interface IPseudoClassSelectorFactory`
  - `ISelector Create(string name)`

`interface IPseudoElementSelectorFactory`
  - `ISelector Create(string name)`

`interface ISelectorVisitor`
  - `void Attribute(string name, string op, string value)`
  - `void Child(string name, int step, int offset, ISelector selector)`
  - `void Class(string name)`
  - `void Combinator(IEnumerable<ISelector> selectors, IEnumerable<string> symbols)`
  - `void Id(string value)`
  - `void List(IEnumerable<ISelector> selectors)`
  - `void Many(IEnumerable<ISelector> selectors)`
  - `void PseudoClass(string name)`
  - `void PseudoElement(string name)`
  - `void Type(string name)`

`interface IStylingService`
  - `Task<IStyleSheet> ParseStylesheetAsync(IResponse response, StyleOptions options, CancellationToken cancel)`
  - `bool SupportsType(string mimeType)`

`class CssSelectorParser`
  - `CssSelectorParser()`
  - `ISelector ParseSelector(string selectorText)`

`class CssStringSourceExtensions`
  - `string ConsumeEscape(StringSource source)`
  - `bool IsValidEscape(StringSource source)`
  - `char SkipCssComment(StringSource source)`

`interface ICssSelectorParser`
  - `ISelector ParseSelector(string selectorText)`

`struct Priority`
  - `Priority(UInt32 priority)`
  - `Priority(byte inlines, byte ids, byte classes, byte tags)`
  - `int CompareTo(Priority other)`
  - `bool Equals(Priority other)`
  - `bool Equals(object obj)`
  - `int GetHashCode()`
  - `string ToString()`
  - `byte Classes { get; }`
  - `byte Ids { get; }`
  - `byte Inlines { get; }`
  - `byte Tags { get; }`

`class StyleOptions`
  - `StyleOptions(IDocument document)`
  - `IDocument Document { get; }`
  - `IElement Element { get; set; }`
  - `bool IsAlternate { get; set; }`
  - `bool IsDisabled { get; set; }`

`enum AdjacentPosition`
  - `values: BeforeBegin, AfterBegin, BeforeEnd, AfterEnd`

`class Attr`
  - `Attr(string localName)`
  - `Attr(string localName, string value)`
  - `Attr(string prefix, string localName, string value, string namespaceUri)`
  - `bool Equals(IAttr other)`
  - `int GetHashCode()`
  - `bool IsId { get; }`
  - `bool IsSpecified { get; }`
  - `string LocalName { get; }`
  - `string Name { get; }`
  - `string NamespaceUri { get; }`
  - `IElement OwnerElement { get; }`
  - `string Prefix { get; }`
  - `bool Specified { get; }`
  - `string Value { get; set; }`

`class AttrExtensions`
  - `INamedNodeMap Clear(INamedNodeMap attributes)`
  - `bool SameAs(INamedNodeMap sourceAttributes, INamedNodeMap targetAttributes)`

`class CollectionExtensions`
  - `bool Accepts(FilterSettings filter, INode node)`
  - `IElement GetElementById(INodeList children, string id)`
  - `T GetElementById<T>(IEnumerable<T> elements, string id)`
  - `void GetElementsByName(INodeList children, string name, List<IElement> result)`
  - `IEnumerable<T> GetNodes<T>(INode parent, bool deep = ..., Func<T, bool> predicate = ...)`

`class CreateDocumentOptions`
  - `CreateDocumentOptions(IResponse response, Encoding encoding = ..., IDocument ancestor = ...)`
  - `MimeType ContentType { get; }`
  - `IDocument ImportAncestor { get; }`
  - `IResponse Response { get; }`
  - `TextSource Source { get; }`

`class DefaultAttributeObserver`
  - `DefaultAttributeObserver()`
  - `void RegisterObserver<TElement>(string expectedName, Action<TElement, string> callback)`

`class DefaultDocumentFactory`
  - `DefaultDocumentFactory()`
  - `Task<IDocument> CreateAsync(IBrowsingContext context, CreateDocumentOptions options, CancellationToken cancellationToken)`
  - `void Register(string contentType, Creator creator)`
  - `Creator Unregister(string contentType)`

`enum DirectionMode`
  - `values: Ltr, Rtl`

`class Document`
  - `Document(IBrowsingContext context, TextSource source)`
  - `bool AddImportUrl(Uri uri)`
  - `INode Adopt(INode externalNode)`
  - `void Append(INode[] nodes)`
  - `void Clear()`
  - `IAttr CreateAttribute(string localName)`
  - `IAttr CreateAttribute(string namespaceUri, string qualifiedName)`
  - `IComment CreateComment(string data)`
  - `IDocumentFragment CreateDocumentFragment()`
  - `IElement CreateElement(string localName)`
  - `IElement CreateElement(string namespaceUri, string qualifiedName)`
  - `Element CreateElementFrom(string name, string prefix, NodeFlags flags = ...)`
  - `Event CreateEvent(string type)`
  - `INodeIterator CreateNodeIterator(INode root, FilterSettings settings = ..., NodeFilter filter = ...)`
  - `IProcessingInstruction CreateProcessingInstruction(string target, string data)`
  - `IRange CreateRange()`
  - `IText CreateTextNode(string data)`
  - `ITreeWalker CreateTreeWalker(INode root, FilterSettings settings = ..., NodeFilter filter = ...)`
  - `void DelayLoad(Task task)`
  - `void Dispose()`
  - `void EnableStyleSheetsForSet(string name)`
  - `IElement GetElementById(string elementId)`
  - `IHtmlCollection<IElement> GetElementsByClassName(string classNames)`
  - `IHtmlCollection<IElement> GetElementsByName(string name)`
  - `IHtmlCollection<IElement> GetElementsByTagName(string tagName)`
  - `IHtmlCollection<IElement> GetElementsByTagName(string namespaceURI, string tagName)`
  - `bool HasFocus()`
  - `bool HasImported(Uri uri)`
  - `INode Import(INode externalNode, bool deep = ...)`
  - `void Load(string url)`
  - `IDocument Open(string type = ..., string replace = ...)`
  - `void Prepend(INode[] nodes)`
  - `IElement QuerySelector(string selectors)`
  - `IHtmlCollection<IElement> QuerySelectorAll(string selectors)`
  - `void Setup(IResponse response, MimeType contentType, IDocument importAncestor)`
  - `void Write(string content)`
  - `void WriteLine(string content)`
  - `... (properties omitted)`

`class DocumentExtensions`
  - `void AdoptNode(IDocument document, INode node)`
  - `TElement CreateElement<TElement>(IDocument document)`
  - `IEnumerable<IDownload> GetDownloads(IDocument document)`
  - `IEnumerable<Task> GetScriptDownloads(IDocument document)`
  - `IEnumerable<Task> GetStyleSheetDownloads(IDocument document)`
  - `Task WaitForReadyAsync(IDocument document)`

`enum DocumentPositions`
  - `values: Same, Disconnected, Preceding, Following, Contains, ContainedBy, ImplementationSpecific`

`enum DocumentReadyState`
  - `values: Loading, Interactive, Complete`

`class DomElementExtensions`
  - `IAttr GetAttributeNode(IElement element, string name)`
  - `IAttr GetAttributeNode(IElement element, string namespaceUri, string localName)`

`enum DomError`
  - `values: IndexSizeError, DomStringSize, HierarchyRequest, WrongDocument, InvalidCharacter, NoDataAllowed, NoModificationAllowed, NotFound, NotSupported, InUse, InvalidState, Syntax, InvalidModification, Namespace, InvalidAccess, Validation, TypeMismatch, Security, Network, Abort, UrlMismatch, QuotaExceeded, Timeout, InvalidNodeType, DataClone`

`class DomEventHandler`
  - `DomEventHandler(object object, IntPtr method)`
  - `IAsyncResult BeginInvoke(object sender, Event ev, AsyncCallback callback, object object)`
  - `void EndInvoke(IAsyncResult result)`
  - `void Invoke(object sender, Event ev)`

`class DomException`
  - `DomException(DomError code)`
  - `DomException(string message)`
  - `int Code { get; }`
  - `string Name { get; }`

`class Element`
  - `Element(Document owner, string localName, string prefix, string namespaceUri, NodeFlags flags = ...)`
  - `Element(Document owner, string name, string localName, string prefix, string namespaceUri, NodeFlags flags = ...)`
  - `void AddAttribute(Attr attr)`
  - `void After(INode[] nodes)`
  - `void Append(INode[] nodes)`
  - `IShadowRoot AttachShadow(ShadowRootMode mode = ...)`
  - `void Before(INode[] nodes)`
  - `Node Clone(Document owner, bool deep)`
  - `IElement Closest(string selectorText)`
  - `bool Equals(INode otherNode)`
  - `string GetAttribute(string name)`
  - `string GetAttribute(string namespaceUri, string localName)`
  - `IHtmlCollection<IElement> GetElementsByClassName(string classNames)`
  - `IHtmlCollection<IElement> GetElementsByTagName(string tagName)`
  - `IHtmlCollection<IElement> GetElementsByTagNameNS(string namespaceURI, string tagName)`
  - `bool HasAttribute(string name)`
  - `bool HasAttribute(StringOrMemory name)`
  - `bool HasAttribute(string namespaceUri, string localName)`
  - `void Insert(AdjacentPosition position, string html)`
  - `bool Matches(string selectorText)`
  - `IElement ParseSubtree(string source)`
  - `void Prepend(INode[] nodes)`
  - `IElement QuerySelector(string selectors)`
  - `IHtmlCollection<IElement> QuerySelectorAll(string selectors)`
  - `void Remove()`
  - `bool RemoveAttribute(string name)`
  - `bool RemoveAttribute(string namespaceUri, string localName)`
  - `void Replace(INode[] nodes)`
  - `void SetAttribute(string name, string value)`
  - `void SetAttribute(string namespaceUri, string name, string value)`
  - `IElement AssignedSlot { get; }`
  - `int ChildElementCount { get; }`
  - `IHtmlCollection<IElement> Children { get; }`
  - `ITokenList ClassList { get; }`
  - `string ClassName { get; set; }`
  - `IElement FirstElementChild { get; }`
  - `string GivenNamespaceUri { get; }`
  - `string Id { get; set; }`
  - `string InnerHtml { get; set; }`
  - `bool IsFocused { get; set; }`
  - `IElement LastElementChild { get; }`
  - `string LocalName { get; }`
  - `string NamespaceUri { get; }`
  - `IElement NextElementSibling { get; }`
  - `string OuterHtml { get; set; }`
  - `string Prefix { get; }`
  - `IElement PreviousElementSibling { get; }`
  - `IShadowRoot ShadowRoot { get; }`
  - `string Slot { get; set; }`
  - `ISourceReference SourceReference { get; set; }`
  - `string TagName { get; }`
  - `string TextContent { get; set; }`

`class ElementExtensions`
  - `T AddClass<T>(T elements, string className)`
  - `T After<T>(T elements, string html)`
  - `T Append<T>(T elements, string html)`
  - `T Attr<T>(T elements, string attributeName, string attributeValue)`
  - `T Attr<T>(T elements, IEnumerable<KeyValuePair<string, string>> attributes)`
  - `T Attr<T>(T elements, object attributes)`
  - `IEnumerable<string> Attr<T>(T elements, string attributeName)`
  - `T Before<T>(T elements, string html)`
  - `IElement ClearAttr(IElement element)`
  - `T ClearAttr<T>(T elements)`
  - `ResourceRequest CreateRequestFor(IElement element, Url url)`
  - `IElement Empty(IElement element)`
  - `T Empty<T>(T elements)`
  - `string GetCssNamespace(IElement el, string prefix)`
  - `string GetNamespaceUri(IElement element)`
  - `string GetProperty(IHtmlMetaElement element)`
  - `string GetSelector(IElement element)`
  - `bool HasClass(IEnumerable<IElement> elements, string className)`
  - `string Html(IElement element)`
  - `T Html<T>(T elements, string html)`
  - `bool IsActive(IElement element)`
  - `bool IsChecked(IElement element)`
  - `bool IsDefault(IElement element)`
  - `bool IsDisabled(IElement element)`
  - `bool IsEditable(IElement element)`
  - `bool IsEnabled(IElement element)`
  - `bool IsFirstChild(IElement element)`
  - `bool IsFirstOfType(IElement element)`
  - `bool IsHovered(IElement element)`
  - `bool IsInRange(IElement element)`
  - `bool IsIndeterminate(IElement element)`
  - `bool IsInvalid(IElement element)`
  - `bool IsLastChild(IElement element)`
  - `bool IsLastOfType(IElement element)`
  - `bool IsLink(IElement element)`
  - `bool IsMutable(IHtmlInputElement input)`
  - `bool IsMutable(IHtmlTextAreaElement textArea)`
  - `bool IsOnlyChild(IElement element)`
  - `bool IsOnlyOfType(IElement element)`
  - `bool IsOpen(IElement element)`
  - `bool IsOptional(IElement element)`
  - `bool IsOutOfRange(IElement element)`
  - `bool IsPlaceholderShown(IElement element)`
  - `bool IsPseudo(IElement element, string name)`
  - `bool IsReadOnly(IElement element)`
  - `bool IsRequired(IElement element)`
  - `bool IsShadow(IElement element)`
  - `bool IsTarget(IElement element)`
  - `bool IsUnchecked(IElement element)`
  - `bool IsValid(IElement element)`
  - `bool IsVisible(IElement element)`
  - `bool IsVisited(IElement element)`
  - `string LocateNamespaceFor(IElement element, string prefix)`
  - `string LocatePrefixFor(IElement element, string namespaceUri)`
  - `bool MatchesCssNamespace(IElement el, string prefix)`
  - `Task<IDocument> NavigateAsync<TElement>(TElement element)`
  - `Task<IDocument> NavigateAsync<TElement>(TElement element, CancellationToken cancel)`
  - `T Prepend<T>(T elements, string html)`
  - `T RemoveClass<T>(T elements, string className)`
  - `void SetProperty(IHtmlMetaElement element, string value)`
  - `... (properties omitted)`

`class Entity`
  - `Entity(Document owner)`
  - `Entity(Document owner, string name)`
  - `Node Clone(Document newOwner, bool deep)`
  - `string InputEncoding { get; }`
  - `string NodeValue { get; set; }`
  - `string NotationName { get; set; }`
  - `string PublicId { get; }`
  - `string SystemId { get; }`
  - `string TextContent { get; set; }`
  - `string XmlEncoding { get; }`
  - `string XmlVersion { get; }`

`class EventTarget`
  - `void AddEventListener(string type, DomEventHandler callback = ..., bool capture = ...)`
  - `bool Dispatch(Event ev)`
  - `bool HasEventListener(string type)`
  - `void InvokeEventListener(Event ev)`
  - `void RemoveEventListener(string type, DomEventHandler callback = ..., bool capture = ...)`
  - `void RemoveEventListeners()`

`class EventTargetExtensions`
  - `Task<Event> AwaitEventAsync<TEventTarget>(TEventTarget node, string eventName)`
  - `bool Fire(IEventTarget target, Event eventData)`
  - `bool Fire<T>(IEventTarget target, Action<T> initializer, IEventTarget targetOverride = ...)`
  - `bool FireSimpleEvent(IEventTarget target, string eventName, bool bubble = ..., bool cancelable = ...)`

`class CustomEvent`
  - `CustomEvent()`
  - `CustomEvent(string type, bool bubbles = ..., bool cancelable = ..., object details = ...)`
  - `void Init(string type, bool bubbles, bool cancelable, object details)`
  - `object Details { get; set; }`

`class DefaultEventFactory`
  - `DefaultEventFactory()`
  - `Event Create(string name)`
  - `void Register(string name, Creator creator)`
  - `Creator Unregister(string name)`

`class ErrorEvent`
  - `ErrorEvent()`
  - `void Init(string filename, int line, int column, Exception error)`
  - `int Column { get; set; }`
  - `Exception Error { get; set; }`
  - `string FileName { get; set; }`
  - `int Line { get; set; }`
  - `string Message { get; }`

`class Event`
  - `Event()`
  - `Event(string type)`
  - `Event(string type, bool bubbles = ..., bool cancelable = ...)`
  - `Event(string type, bool bubbles = ..., bool cancelable = ..., bool composed = ...)`
  - `void Cancel()`
  - `IEnumerable<IEventTarget> GetComposedPath()`
  - `void Init(string type, bool bubbles, bool cancelable)`
  - `void Stop()`
  - `void StopImmediately()`
  - `IEventTarget CurrentTarget { get; }`
  - `bool IsBubbling { get; }`
  - `bool IsCancelable { get; }`
  - `bool IsComposed { get; }`
  - `bool IsDefaultPrevented { get; }`
  - `bool IsTrusted { get; set; }`
  - `IEventTarget OriginalTarget { get; }`
  - `EventPhase Phase { get; }`
  - `DateTime Time { get; }`
  - `string Type { get; }`

`enum EventPhase`
  - `values: None, Capturing, AtTarget, Bubbling`

`class FocusEvent`
  - `FocusEvent()`
  - `FocusEvent(string type, bool bubbles = ..., bool cancelable = ..., IWindow view = ..., int detail = ..., IEventTarget target = ...)`
  - `void Init(string type, bool bubbles, bool cancelable, IWindow view, int detail, IEventTarget target)`
  - `IEventTarget Target { get; set; }`

`class HashChangedEvent`
  - `HashChangedEvent()`
  - `HashChangedEvent(string type, bool bubbles = ..., bool cancelable = ..., string oldURL = ..., string newURL = ...)`
  - `void Init(string type, bool bubbles, bool cancelable, string previousUrl, string currentUrl)`
  - `string CurrentUrl { get; set; }`
  - `string PreviousUrl { get; set; }`

`interface IEventFactory`
  - `Event Create(string name)`

`interface IMessagePort`
  - `void Close()`
  - `void Open()`
  - `void Send(object message)`

`class MessageEvent`
  - `MessageEvent()`
  - `MessageEvent(string type, bool bubbles = ..., bool cancelable = ..., object data = ..., string origin = ..., string lastEventId = ..., IWindow source = ..., IMessagePort[] ports)`
  - `void Init(string type, bool bubbles, bool cancelable, object data, string origin, string lastEventId, IWindow source, IMessagePort[] ports)`
  - `object Data { get; set; }`
  - `string LastEventId { get; set; }`
  - `string Origin { get; set; }`
  - `IMessagePort[] Ports { get; set; }`
  - `IWindow Source { get; set; }`

`class PageTransitionEvent`
  - `PageTransitionEvent()`
  - `PageTransitionEvent(string type, bool bubbles = ..., bool cancelable = ..., bool persisted = ...)`
  - `void Init(string type, bool bubbles, bool cancelable, bool persisted)`
  - `bool IsPersisted { get; set; }`

`class RequestEvent`
  - `RequestEvent(Request request, IResponse response)`
  - `Request Request { get; }`
  - `IResponse Response { get; }`

`class UiEvent`
  - `UiEvent()`
  - `UiEvent(string type, bool bubbles = ..., bool cancelable = ..., IWindow view = ..., int detail = ...)`
  - `void Init(string type, bool bubbles, bool cancelable, IWindow view, int detail)`
  - `int Detail { get; set; }`
  - `IWindow View { get; set; }`

`enum FilterResult`
  - `values: Accept, Reject, Skip`

`enum FilterSettings`
  - `values: All, Element, Attribute, Text, CharacterData, EntityReference, Entity, ProcessingInstruction, Comment, Document, DocumentType, DocumentFragment, Notation`

`enum HorizontalAlignment`
  - `values: Left, Center, Right, Justify`

`interface IAttr`
  - `bool IsSpecified { get; }`
  - `string LocalName { get; }`
  - `string Name { get; }`
  - `string NamespaceUri { get; }`
  - `IElement OwnerElement { get; }`
  - `string Prefix { get; }`
  - `string Value { get; set; }`

`interface IAttributeObserver`
  - `void NotifyChange(IElement host, string name, string value)`

`interface ICharacterData`
  - `void Append(string value)`
  - `void Delete(int offset, int count)`
  - `void Insert(int offset, string value)`
  - `void Replace(int offset, int count, string value)`
  - `string Substring(int offset, int count)`
  - `string Data { get; set; }`
  - `int Length { get; }`

`interface IChildNode`
  - `void After(INode[] nodes)`
  - `void Before(INode[] nodes)`
  - `void Remove()`
  - `void Replace(INode[] nodes)`

`interface IDocument`
  - `bool AddImportUrl(Uri uri)`
  - `INode Adopt(INode externalNode)`
  - `void Close()`
  - `IAttr CreateAttribute(string name)`
  - `IAttr CreateAttribute(string namespaceUri, string name)`
  - `IComment CreateComment(string data)`
  - `IDocumentFragment CreateDocumentFragment()`
  - `IElement CreateElement(string name)`
  - `IElement CreateElement(string namespaceUri, string name)`
  - `Event CreateEvent(string type)`
  - `INodeIterator CreateNodeIterator(INode root, FilterSettings settings = ..., NodeFilter filter = ...)`
  - `IProcessingInstruction CreateProcessingInstruction(string target, string data)`
  - `IRange CreateRange()`
  - `IText CreateTextNode(string data)`
  - `ITreeWalker CreateTreeWalker(INode root, FilterSettings settings = ..., NodeFilter filter = ...)`
  - `bool ExecuteCommand(string commandId, bool showUserInterface = ..., string value = ...)`
  - `string GetCommandValue(string commandId)`
  - `IHtmlCollection<IElement> GetElementsByClassName(string classNames)`
  - `IHtmlCollection<IElement> GetElementsByName(string name)`
  - `IHtmlCollection<IElement> GetElementsByTagName(string tagName)`
  - `IHtmlCollection<IElement> GetElementsByTagName(string namespaceUri, string tagName)`
  - `bool HasFocus()`
  - `bool HasImported(Uri uri)`
  - `INode Import(INode externalNode, bool deep = ...)`
  - `bool IsCommandEnabled(string commandId)`
  - `bool IsCommandExecuted(string commandId)`
  - `bool IsCommandIndeterminate(string commandId)`
  - `bool IsCommandSupported(string commandId)`
  - `void Load(string url)`
  - `IDocument Open(string type = ..., string replace = ...)`
  - `void Write(string content)`
  - `void WriteLine(string content)`
  - `... (properties omitted)`

`interface IDocumentFactory`
  - `Task<IDocument> CreateAsync(IBrowsingContext context, CreateDocumentOptions options, CancellationToken cancellationToken)`

`interface IDocumentStyle`
  - `void EnableStyleSheetsForSet(string name)`
  - `string LastStyleSheetSet { get; }`
  - `string PreferredStyleSheetSet { get; }`
  - `string SelectedStyleSheetSet { get; set; }`
  - `IStringList StyleSheetSets { get; }`
  - `IStyleSheetList StyleSheets { get; }`

`interface IDocumentType`
  - `string Name { get; }`
  - `string PublicIdentifier { get; }`
  - `string SystemIdentifier { get; }`

`interface IDomException`
  - `int Code { get; }`

`interface IElement`
  - `IShadowRoot AttachShadow(ShadowRootMode mode = ...)`
  - `IElement Closest(string selectors)`
  - `string GetAttribute(string name)`
  - `string GetAttribute(string namespaceUri, string localName)`
  - `IHtmlCollection<IElement> GetElementsByClassName(string classNames)`
  - `IHtmlCollection<IElement> GetElementsByTagName(string tagName)`
  - `IHtmlCollection<IElement> GetElementsByTagNameNS(string namespaceUri, string tagName)`
  - `bool HasAttribute(string name)`
  - `bool HasAttribute(string namespaceUri, string localName)`
  - `void Insert(AdjacentPosition position, string html)`
  - `bool Matches(string selectors)`
  - `bool RemoveAttribute(string name)`
  - `bool RemoveAttribute(string namespaceUri, string localName)`
  - `void SetAttribute(string name, string value)`
  - `void SetAttribute(string namespaceUri, string name, string value)`
  - `IElement AssignedSlot { get; }`
  - `INamedNodeMap Attributes { get; }`
  - `ITokenList ClassList { get; }`
  - `string ClassName { get; set; }`
  - `string GivenNamespaceUri { get; }`
  - `string Id { get; set; }`
  - `string InnerHtml { get; set; }`
  - `bool IsFocused { get; }`
  - `string LocalName { get; }`
  - `string NamespaceUri { get; }`
  - `string OuterHtml { get; set; }`
  - `string Prefix { get; }`
  - `IShadowRoot ShadowRoot { get; }`
  - `string Slot { get; set; }`
  - `ISourceReference SourceReference { get; }`
  - `string TagName { get; }`

`interface IElementFactory<TDocument, TElement>`
  - `TElement Create(TDocument document, string localName, string prefix = ..., NodeFlags flags = ...)`

`interface IEntityProvider`
  - `string GetSymbol(string name)`

`interface IEntityProviderExtended`
  - `string GetSymbol(StringOrMemory name)`

`interface IEventTarget`
  - `void AddEventListener(string type, DomEventHandler callback = ..., bool capture = ...)`
  - `bool Dispatch(Event ev)`
  - `void InvokeEventListener(Event ev)`
  - `void RemoveEventListener(string type, DomEventHandler callback = ..., bool capture = ...)`

`interface IHtmlCollection<T>`
  - `T Item { get; }`
  - `int Length { get; }`

`interface IImplementation`
  - `IDocumentType CreateDocumentType(string qualifiedName, string publicId, string systemId)`
  - `IDocument CreateHtmlDocument(string title)`
  - `bool HasFeature(string feature, string version = ...)`

`interface ILinkImport`
  - `IDocument Import { get; }`

`interface ILinkStyle`
  - `IStyleSheet Sheet { get; }`

`interface ILocation`
  - `void Assign(string url)`
  - `void Reload()`
  - `void Replace(string url)`

`interface IMutationRecord`
  - `INodeList Added { get; }`
  - `string AttributeName { get; }`
  - `string AttributeNamespace { get; }`
  - `INode NextSibling { get; }`
  - `INode PreviousSibling { get; }`
  - `string PreviousValue { get; }`
  - `INodeList Removed { get; }`
  - `INode Target { get; }`
  - `string Type { get; }`

`interface INamedNodeMap`
  - `IAttr GetNamedItem(string name)`
  - `IAttr GetNamedItem(string namespaceUri, string localName)`
  - `IAttr RemoveNamedItem(string name)`
  - `IAttr RemoveNamedItem(string namespaceUri, string localName)`
  - `IAttr SetNamedItem(IAttr item)`
  - `IAttr SetNamedItemWithNamespaceUri(IAttr item)`
  - `IAttr Item { get; }`
  - `IAttr Item { get; }`
  - `int Length { get; }`

`interface INode`
  - `INode AppendChild(INode child)`
  - `INode Clone(bool deep = ...)`
  - `DocumentPositions CompareDocumentPosition(INode otherNode)`
  - `bool Contains(INode otherNode)`
  - `bool Equals(INode otherNode)`
  - `INode InsertBefore(INode newElement, INode referenceElement)`
  - `bool IsDefaultNamespace(string namespaceUri)`
  - `string LookupNamespaceUri(string prefix)`
  - `string LookupPrefix(string namespaceUri)`
  - `void Normalize()`
  - `INode RemoveChild(INode child)`
  - `INode ReplaceChild(INode newChild, INode oldChild)`
  - `string BaseUri { get; }`
  - `Url BaseUrl { get; }`
  - `INodeList ChildNodes { get; }`
  - `INode FirstChild { get; }`
  - `NodeFlags Flags { get; }`
  - `bool HasChildNodes { get; }`
  - `INode LastChild { get; }`
  - `INode NextSibling { get; }`
  - `string NodeName { get; }`
  - `NodeType NodeType { get; }`
  - `string NodeValue { get; set; }`
  - `IDocument Owner { get; }`
  - `INode Parent { get; }`
  - `IElement ParentElement { get; }`
  - `INode PreviousSibling { get; }`
  - `string TextContent { get; set; }`

`interface INodeIterator`
  - `INode Next()`
  - `INode Previous()`
  - `NodeFilter Filter { get; }`
  - `bool IsBeforeReference { get; }`
  - `INode Reference { get; }`
  - `INode Root { get; }`
  - `FilterSettings Settings { get; }`

`interface INodeList`
  - `INode Item { get; }`
  - `int Length { get; }`

`interface INonDocumentTypeChildNode`
  - `IElement NextElementSibling { get; }`
  - `IElement PreviousElementSibling { get; }`

`interface INonElementParentNode`
  - `IElement GetElementById(string elementId)`

`interface IParentNode`
  - `void Append(INode[] nodes)`
  - `void Prepend(INode[] nodes)`
  - `IElement QuerySelector(string selectors)`
  - `IHtmlCollection<IElement> QuerySelectorAll(string selectors)`
  - `int ChildElementCount { get; }`
  - `IHtmlCollection<IElement> Children { get; }`
  - `IElement FirstElementChild { get; }`
  - `IElement LastElementChild { get; }`

`interface IProcessingInstruction`
  - `string Target { get; }`

`interface IPseudoElement`
  - `string PseudoName { get; }`

`interface IRange`
  - `void ClearContent()`
  - `IRange Clone()`
  - `void Collapse(bool toStart)`
  - `RangePosition CompareBoundaryTo(RangeType how, IRange sourceRange)`
  - `RangePosition CompareTo(INode node, int offset)`
  - `bool Contains(INode node, int offset)`
  - `IDocumentFragment CopyContent()`
  - `void Detach()`
  - `void EndAfter(INode refNode)`
  - `void EndBefore(INode refNode)`
  - `void EndWith(INode refNode, int offset)`
  - `IDocumentFragment ExtractContent()`
  - `void Insert(INode node)`
  - `bool Intersects(INode node)`
  - `void Select(INode refNode)`
  - `void SelectContent(INode refNode)`
  - `void StartAfter(INode refNode)`
  - `void StartBefore(INode refNode)`
  - `void StartWith(INode refNode, int offset)`
  - `void Surround(INode newParent)`
  - `INode CommonAncestor { get; }`
  - `int End { get; }`
  - `INode Head { get; }`
  - `bool IsCollapsed { get; }`
  - `int Start { get; }`
  - `INode Tail { get; }`

`interface IReverseEntityProvider`
  - `string GetName(string symbol)`

`interface ISettableTokenList`
  - `string Value { get; set; }`

`interface IShadowRoot`
  - `IElement ActiveElement { get; }`
  - `IElement Host { get; }`
  - `string InnerHtml { get; set; }`
  - `ShadowRootMode Mode { get; }`
  - `IStyleSheetList StyleSheets { get; }`

`interface ISourceReference`
  - `TextPosition Position { get; }`

`interface IStringList`
  - `bool Contains(string entry)`
  - `int Length { get; }`

`interface IStringMap`
  - `void Remove(string name)`
  - `string Item { get; set; }`

`interface IStyleSheet`
  - `string LocateNamespace(string prefix)`
  - `void SetOwner(IElement element)`
  - `IBrowsingContext Context { get; }`
  - `string Href { get; }`
  - `bool IsDisabled { get; set; }`
  - `IMediaList Media { get; }`
  - `IElement OwnerNode { get; }`
  - `TextSource Source { get; }`
  - `string Title { get; }`
  - `string Type { get; }`

`interface IStyleSheetList`
  - `IStyleSheet Item { get; }`
  - `int Length { get; }`

`interface IText`
  - `IText Split(int offset)`
  - `IElement AssignedSlot { get; }`
  - `string Text { get; }`

`interface ITokenList`
  - `void Add(string[] tokens)`
  - `bool Contains(string token)`
  - `void Remove(string[] tokens)`
  - `bool Toggle(string token, bool force = ...)`
  - `int Length { get; }`

`interface ITreeWalker`
  - `INode ToFirst()`
  - `INode ToLast()`
  - `INode ToNext()`
  - `INode ToNextSibling()`
  - `INode ToParent()`
  - `INode ToPrevious()`
  - `INode ToPreviousSibling()`
  - `INode Current { get; set; }`
  - `NodeFilter Filter { get; }`
  - `INode Root { get; }`
  - `FilterSettings Settings { get; }`

`interface IUrlUtilities`
  - `string Hash { get; set; }`
  - `string Host { get; set; }`
  - `string HostName { get; set; }`
  - `string Href { get; set; }`
  - `string Origin { get; }`
  - `string Password { get; set; }`
  - `string PathName { get; set; }`
  - `string Port { get; set; }`
  - `string Protocol { get; set; }`
  - `string Search { get; set; }`
  - `string UserName { get; set; }`

`interface IWindow`
  - `void Alert(string message)`
  - `void Blur()`
  - `void Close()`
  - `bool Confirm(string message)`
  - `void Focus()`
  - `IWindow Open(string url = ..., string name = ..., string features = ..., string replace = ...)`
  - `void Print()`
  - `void Stop()`
  - `IDocument Document { get; }`
  - `IHistory History { get; }`
  - `bool IsClosed { get; }`
  - `ILocation Location { get; }`
  - `string Name { get; set; }`
  - `INavigator Navigator { get; }`
  - `int OuterHeight { get; }`
  - `int OuterWidth { get; }`
  - `IWindow Proxy { get; }`
  - `int ScreenX { get; }`
  - `int ScreenY { get; }`
  - `string Status { get; set; }`

`interface IWindowTimers`
  - `void ClearInterval(int handle = ...)`
  - `void ClearTimeout(int handle = ...)`
  - `int SetInterval(Action<IWindow> handler, int timeout = ...)`
  - `int SetTimeout(Action<IWindow> handler, int timeout = ...)`

`class MutationCallback`
  - `MutationCallback(object object, IntPtr method)`
  - `IAsyncResult BeginInvoke(IMutationRecord[] mutations, MutationObserver observer, AsyncCallback callback, object object)`
  - `void EndInvoke(IAsyncResult result)`
  - `void Invoke(IMutationRecord[] mutations, MutationObserver observer)`

`class MutationObserver`
  - `MutationObserver(MutationCallback callback)`
  - `void Connect(INode target, bool childList = ..., bool subtree = ..., Nullable<bool> attributes = ..., Nullable<bool> characterData = ..., Nullable<bool> attributeOldValue = ..., Nullable<bool> characterDataOldValue = ..., IEnumerable<string> attributeFilter = ...)`
  - `void Disconnect()`
  - `IEnumerable<IMutationRecord> Flush()`

`class Node`
  - `Node(Document owner, string name, NodeType type = ..., NodeFlags flags = ...)`
  - `void AddNode(Node node)`
  - `INode AppendChild(INode child)`
  - `void AppendText(string s)`
  - `Node Clone(Document newOwner, bool deep)`
  - `INode Clone(bool deep = ...)`
  - `DocumentPositions CompareDocumentPosition(INode otherNode)`
  - `bool Contains(INode otherNode)`
  - `bool Equals(INode otherNode)`
  - `INode InsertBefore(INode newElement, INode referenceElement)`
  - `INode InsertChild(int index, INode child)`
  - `void InsertNode(int index, Node node)`
  - `void InsertText(int index, string s)`
  - `bool IsDefaultNamespace(string namespaceUri)`
  - `string LookupNamespaceUri(string prefix)`
  - `string LookupPrefix(string namespaceUri)`
  - `void Normalize()`
  - `INode RemoveChild(INode child)`
  - `void RemoveNode(int index, Node node)`
  - `INode ReplaceChild(INode newChild, INode oldChild)`
  - `void ToHtml(TextWriter writer, IMarkupFormatter formatter)`
  - `string BaseUri { get; }`
  - `Url BaseUrl { get; set; }`
  - `NodeFlags Flags { get; }`
  - `bool HasChildNodes { get; }`
  - `string NodeName { get; }`
  - `NodeType NodeType { get; }`
  - `string NodeValue { get; set; }`
  - `IElement ParentElement { get; }`
  - `string TextContent { get; set; }`

`class NodeExtensions`
  - `void EnsurePreInsertionValidity(INode parent, INode node, INode child)`
  - `TNode FindChild<TNode>(INode parent)`
  - `TNode FindDescendant<TNode>(INode parent, int maxDepth = ...)`
  - `T GetAncestor<T>(INode node)`
  - `IEnumerable<INode> GetAncestors(INode node)`
  - `IElement GetAssignedSlot(IShadowRoot root, string name)`
  - `INode GetAssociatedHost(INode node)`
  - `IEnumerable<INode> GetDescendants(INode parent)`
  - `IEnumerable<INode> GetDescendantsAndSelf(INode parent)`
  - `int GetElementCount(INode parent)`
  - `IEnumerable<INode> GetInclusiveAncestors(INode node)`
  - `INode GetRoot(INode node)`
  - `bool HasDataListAncestor(INode child)`
  - `bool HasTextNodes(INode node)`
  - `Url HyperReference(INode node, string url)`
  - `int Index(INode node)`
  - `int Index(IEnumerable<INode> nodes, INode item)`
  - `int IndexOf(INode parent, INode node)`
  - `bool IsAncestorOf(INode parent, INode node)`
  - `bool IsDescendantOf(INode node, INode parent)`
  - `bool IsEndPoint(INode node)`
  - `bool IsEndPoint(NodeType type)`
  - `bool IsFollowedByDoctype(INode child)`
  - `bool IsFollowing(INode after, INode before)`
  - `bool IsHostIncludingInclusiveAncestor(INode parent, INode node)`
  - `bool IsInclusiveAncestorOf(INode parent, INode node)`
  - `bool IsInclusiveDescendantOf(INode node, INode parent)`
  - `bool IsInsertable(INode node)`
  - `bool IsPrecededByElement(INode child)`
  - `bool IsPreceding(INode before, INode after)`
  - `bool IsSiblingOf(INode node, INode element)`
  - `INode PreInsert(INode parent, INode node, INode child)`
  - `INode PreRemove(INode parent, INode child)`
  - `string Text(INode node)`
  - `T Text<T>(T nodes, string text)`

`class NodeFilter`
  - `NodeFilter(object object, IntPtr method)`
  - `IAsyncResult BeginInvoke(INode node, AsyncCallback callback, object object)`
  - `FilterResult EndInvoke(IAsyncResult result)`
  - `FilterResult Invoke(INode node)`

`enum NodeFlags`
  - `values: None, SelfClosing, Special, LiteralText, LineTolerance, ImplicitlyClosed, ImpliedEnd, Scoped, HtmlMember, HtmlTip, HtmlFormatting, HtmlListScoped, HtmlSelectScoped, HtmlTableSectionScoped, HtmlTableScoped, MathMember, MathTip, SvgMember, SvgTip`

`enum NodeType`
  - `values: Element, Attribute, Text, CharacterData, EntityReference, Entity, ProcessingInstruction, Comment, Document, DocumentType, DocumentFragment, Notation`

`class Notation`
  - `Notation(Document owner, string name)`
  - `Node Clone(Document newOwner, bool deep)`
  - `string PublicId { get; set; }`
  - `string SystemId { get; set; }`

`class ParentNodeExtensions`
  - `IEnumerable<TNode> Ancestors<TNode>(INode child)`
  - `IEnumerable<INode> Ancestors(INode child)`
  - `TElement AppendElement<TElement>(INode parent, TElement element)`
  - `void AppendNodes(INode parent, INode[] nodes)`
  - `IEnumerable<TNode> Descendants<TNode>(INode parent)`
  - `IEnumerable<INode> Descendants(INode parent)`
  - `IEnumerable<TNode> DescendantsAndSelf<TNode>(INode parent)`
  - `IEnumerable<INode> DescendantsAndSelf(INode parent)`
  - `IEnumerable<TNode> Descendents<TNode>(INode parent)`
  - `IEnumerable<INode> Descendents(INode parent)`
  - `IEnumerable<TNode> DescendentsAndSelf<TNode>(INode parent)`
  - `IEnumerable<INode> DescendentsAndSelf(INode parent)`
  - `void InsertAfter(INode child, INode[] nodes)`
  - `void InsertBefore(INode child, INode[] nodes)`
  - `TElement InsertElement<TElement>(INode parent, TElement newElement, INode referenceElement)`
  - `void PrependNodes(INode parent, INode[] nodes)`
  - `TElement QuerySelector<TElement>(IParentNode parent, string selectors)`
  - `IEnumerable<TElement> QuerySelectorAll<TElement>(IParentNode parent, string selectors)`
  - `TElement RemoveElement<TElement>(INode parent, TElement element)`
  - `void RemoveFromParent(INode child)`
  - `void ReplaceWith(INode child, INode[] nodes)`

`class QueryExtensions`
  - `bool Contains(ITokenList list, string[] tokens)`
  - `bool Contains<T>(T list, string[] tokens)`
  - `IHtmlCollection<IElement> GetElementsByClassName(INodeList elements, string classNames)`
  - `IHtmlCollection<IElement> GetElementsByClassName<T>(T elements, string classNames)`
  - `IHtmlCollection<IElement> GetElementsByTagName(INodeList elements, string tagName)`
  - `IHtmlCollection<IElement> GetElementsByTagName<T>(T elements, string tagName)`
  - `IHtmlCollection<IElement> GetElementsByTagName(INodeList elements, string namespaceUri, string localName)`
  - `IHtmlCollection<IElement> GetElementsByTagName<T>(T elements, string namespaceUri, string localName)`
  - `IElement QuerySelector(INodeList nodes, string selectorText, INode scopeNode = ...)`
  - `IElement QuerySelector<T>(T nodes, string selectorText, INode scopeNode = ...)`
  - `T QuerySelector<T>(INodeList elements, ISelector selectors)`
  - `T QuerySelector<TNodeList, T>(TNodeList elements, ISelector selectors)`
  - `IElement QuerySelector(INodeList elements, ISelector selector)`
  - `IElement QuerySelector<T>(T elements, ISelector selector)`
  - `IHtmlCollection<IElement> QuerySelectorAll(INodeList nodes, string selectorText, INode scopeNode = ...)`
  - `IHtmlCollection<IElement> QuerySelectorAll<T>(T nodes, string selectorText, INode scopeNode = ...)`
  - `IHtmlCollection<IElement> QuerySelectorAll(INodeList elements, ISelector selector)`
  - `IHtmlCollection<IElement> QuerySelectorAll<T>(T elements, ISelector selector)`
  - `void QuerySelectorAll(INodeList elements, ISelector selector, List<IElement> result)`
  - `void QuerySelectorAll<T>(T elements, ISelector selector, List<IElement> result)`
  - `void QuerySelectorAll<T>(T elements, ISelector selector, IElement scope, List<IElement> result)`

`enum QuirksMode`
  - `values: Off, Limited, On`

`enum RangePosition`
  - `values: Before, Equal, After`

`enum RangeType`
  - `values: StartToStart, StartToEnd, EndToEnd, EndToStart`

`class SelectorExtensions`
  - `IEnumerable<IElement> Children(IEnumerable<IElement> elements, string selectorText = ...)`
  - `IEnumerable<IElement> Children(IEnumerable<IElement> elements, ISelector selector = ...)`
  - `T Eq<T>(IEnumerable<T> elements, int index)`
  - `IEnumerable<T> Even<T>(IEnumerable<T> elements)`
  - `IEnumerable<T> Filter<T>(IEnumerable<T> elements, string selectorText)`
  - `IEnumerable<T> Gt<T>(IEnumerable<T> elements, int index)`
  - `IEnumerable<T> Is<T>(IEnumerable<T> elements, ISelector selector)`
  - `IEnumerable<T> Lt<T>(IEnumerable<T> elements, int index)`
  - `IEnumerable<IElement> Next(IEnumerable<IElement> elements, string selectorText = ...)`
  - `IEnumerable<IElement> Next(IEnumerable<IElement> elements, ISelector selector = ...)`
  - `IEnumerable<T> Not<T>(IEnumerable<T> elements, string selectorText)`
  - `IEnumerable<T> Not<T>(IEnumerable<T> elements, ISelector selector)`
  - `IEnumerable<T> Odd<T>(IEnumerable<T> elements)`
  - `IEnumerable<IElement> Parent(IEnumerable<IElement> elements, string selectorText = ...)`
  - `IEnumerable<IElement> Parent(IEnumerable<IElement> elements, ISelector selector = ...)`
  - `IEnumerable<IElement> Previous(IEnumerable<IElement> elements, string selectorText = ...)`
  - `IEnumerable<IElement> Previous(IEnumerable<IElement> elements, ISelector selector = ...)`
  - `IEnumerable<IElement> Siblings(IEnumerable<IElement> elements, string selectorText = ...)`
  - `IEnumerable<IElement> Siblings(IEnumerable<IElement> elements, ISelector selector = ...)`

`enum ShadowRootMode`
  - `values: Open, Closed`

`class Url`
  - `Url(string url, string baseAddress = ...)`
  - `Url(string address)`
  - `Url(Url baseAddress, string relativeAddress)`
  - `Url(Url address)`
  - `Url Convert(Uri uri)`
  - `Url Create(string address)`
  - `bool Equals(object obj)`
  - `bool Equals(Url other)`
  - `int GetHashCode()`
  - `string ToJson()`
  - `string ToString()`
  - `string Data { get; }`
  - `string Fragment { get; set; }`
  - `string Hash { get; set; }`
  - `string Host { get; set; }`
  - `string HostName { get; set; }`
  - `string Href { get; set; }`
  - `bool IsAbsolute { get; }`
  - `bool IsInvalid { get; }`
  - `bool IsRelative { get; }`
  - `string Origin { get; }`
  - `string Password { get; set; }`
  - `string Path { get; set; }`
  - `string PathName { get; set; }`
  - `string Port { get; set; }`
  - `string Protocol { get; set; }`
  - `string Query { get; set; }`
  - `string Scheme { get; set; }`
  - `string Search { get; set; }`
  - `UrlSearchParams SearchParams { get; }`
  - `string UserName { get; set; }`

`class UrlSearchParams`
  - `UrlSearchParams()`
  - `UrlSearchParams(string init)`
  - `void Append(string name, string value)`
  - `void Delete(string name)`
  - `string Get(string name)`
  - `string[] GetAll(string name)`
  - `bool Has(string name)`
  - `void Set(string name, string value)`
  - `void Sort()`
  - `string ToString()`

`enum VerticalAlignment`
  - `values: Baseline, Sub, Super, TextTop, TextBottom, Middle, Top, Bottom`

`enum Visibility`
  - `values: Visible, Hidden, Collapse`

`enum WordBreak`
  - `values: Normal, BreakAll, KeepAll`

`class FormatExtensions`
  - `string Minify(IMarkupFormattable markup)`
  - `string Prettify(IMarkupFormattable markup)`
  - `string ToCss(IStyleFormattable style)`
  - `string ToCss(IStyleFormattable style, IStyleFormatter formatter)`
  - `void ToCss(IStyleFormattable style, TextWriter writer)`
  - `Task ToCssAsync(IStyleFormattable style, TextWriter writer)`
  - `Task ToCssAsync(IStyleFormattable style, Stream stream)`
  - `string ToHtml(IMarkupFormattable markup)`
  - `string ToHtml(IMarkupFormattable markup, IMarkupFormatter formatter)`
  - `void ToHtml(IMarkupFormattable markup, TextWriter writer)`
  - `Task ToHtmlAsync(IMarkupFormattable markup, TextWriter writer)`
  - `Task ToHtmlAsync(IMarkupFormattable markup, Stream stream)`

`interface IConstructableAttr`
  - `StringOrMemory Name { get; }`
  - `StringOrMemory Value { get; set; }`

`interface IConstructableDocument`
  - `void AddComment(StructHtmlToken token)`
  - `void ApplyManifest()`
  - `void Clear()`
  - `Task FinishLoadingAsync()`
  - `void PerformMicrotaskCheckpoint()`
  - `void ProvideStableState()`
  - `void TrackError(Exception exception)`
  - `Task WaitForReadyAsync(CancellationToken cancelToken)`
  - `IDisposable Builder { get; set; }`
  - `IConstructableElement DocumentElement { get; }`
  - `IConstructableElement Head { get; }`
  - `bool IsLoading { get; }`
  - `QuirksMode QuirksMode { get; set; }`
  - `TextSource Source { get; }`

`interface IConstructableElement`
  - `void AddComment(StructHtmlToken token)`
  - `StringOrMemory GetAttribute(StringOrMemory namespaceUri, StringOrMemory localName)`
  - `bool HasAttribute(StringOrMemory name)`
  - `void SetAttribute(string namespaceUri, StringOrMemory name, StringOrMemory value)`
  - `void SetAttributes(StructAttributes tagAttributes)`
  - `void SetOwnAttribute(StringOrMemory name, StringOrMemory value)`
  - `void SetupElement()`
  - `IConstructableNode ShallowCopy()`
  - `IConstructableNamedNodeMap Attributes { get; }`
  - `StringOrMemory LocalName { get; }`
  - `StringOrMemory NamespaceUri { get; }`
  - `StringOrMemory Prefix { get; }`
  - `ISourceReference SourceReference { get; set; }`

`interface IConstructableMetaElement`
  - `void Handle()`

`interface IConstructableNamedNodeMap`
  - `bool SameAs(IConstructableNamedNodeMap attributes)`
  - `IConstructableAttr Item { get; }`
  - `int Length { get; }`

`interface IConstructableNode`
  - `void AddNode(IConstructableNode node)`
  - `void AppendText(StringOrMemory text, bool emitWhiteSpaceOnly = ...)`
  - `void InsertNode(int idx, IConstructableNode childNode)`
  - `void InsertText(int idx, StringOrMemory text, bool emitWhiteSpaceOnly = ...)`
  - `void RemoveChild(IConstructableNode childNode)`
  - `void RemoveFromParent()`
  - `void RemoveNode(int idx, IConstructableNode childNode)`
  - `IConstructableNodeList ChildNodes { get; }`
  - `NodeFlags Flags { get; }`
  - `StringOrMemory NodeName { get; }`
  - `IConstructableNode Parent { get; set; }`

`interface IConstructableNodeList`
  - `void Clear()`
  - `IConstructableNode Item { get; }`
  - `int Length { get; }`

`interface IConstructableScriptElement`
  - `bool Prepare(IConstructableDocument document)`
  - `Task RunAsync(CancellationToken cancel)`

`interface IConstructableTemplateElement`
  - `void PopulateFragment()`

`interface IDomConstructionElementFactory<TDocument, TElement>`
  - `TElement Create(TDocument document, StringOrMemory localName, StringOrMemory prefix = ..., NodeFlags flags = ...)`
  - `TDocument CreateDocument(TextSource source, IBrowsingContext context = ...)`
  - `IConstructableNode CreateDocumentType(TDocument document, StringOrMemory name, StringOrMemory publicIdentifier, StringOrMemory systemIdentifier)`
  - `IConstructableFormElement CreateForm(TDocument document)`
  - `IConstructableFrameElement CreateFrame(TDocument document)`
  - `IConstructableMathElement CreateMath(TDocument document, StringOrMemory name = ...)`
  - `IConstructableMetaElement CreateMeta(TDocument document)`
  - `TElement CreateNoScript(TDocument document, bool scripting)`
  - `IConstructableScriptElement CreateScript(TDocument document, bool parserInserted, bool started)`
  - `IConstructableSvgElement CreateSvg(TDocument document, StringOrMemory name = ...)`
  - `IConstructableTemplateElement CreateTemplate(TDocument document)`
  - `TElement CreateUnknown(TDocument document, StringOrMemory tagName)`

`class DefaultInputTypeFactory`
  - `DefaultInputTypeFactory()`
  - `BaseInputType Create(IHtmlInputElement input, string type)`
  - `void Register(string type, Creator creator)`
  - `Creator Unregister(string type)`

`class DefaultLinkRelationFactory`
  - `DefaultLinkRelationFactory()`
  - `BaseLinkRelation Create(IHtmlLinkElement link, string rel)`
  - `void Register(string rel, Creator creator)`
  - `Creator Unregister(string rel)`

`class CompositionEvent`
  - `CompositionEvent()`
  - `CompositionEvent(string type, bool bubbles = ..., bool cancelable = ..., IWindow view = ..., string data = ...)`
  - `void Init(string type, bool bubbles, bool cancelable, IWindow view, string data)`
  - `string Data { get; set; }`

`class HtmlErrorEvent`
  - `HtmlErrorEvent(HtmlParseError code, TextPosition position)`
  - `int Code { get; }`
  - `string Message { get; }`
  - `TextPosition Position { get; }`

`class HtmlParseEvent`
  - `HtmlParseEvent(IHtmlDocument document, bool completed)`
  - `IHtmlDocument Document { get; set; }`

`interface ITouchList`
  - `ITouchPoint Item { get; }`
  - `int Length { get; }`

`interface ITouchPoint`
  - `int ClientX { get; }`
  - `int ClientY { get; }`
  - `int Id { get; }`
  - `int PageX { get; }`
  - `int PageY { get; }`
  - `int ScreenX { get; }`
  - `int ScreenY { get; }`
  - `IEventTarget Target { get; }`

`class InputEvent`
  - `InputEvent()`
  - `InputEvent(string type, bool bubbles = ..., bool cancelable = ..., string data = ...)`
  - `void Init(string type, bool bubbles, bool cancelable, string data)`
  - `string Data { get; set; }`

`class KeyboardEvent`
  - `KeyboardEvent()`
  - `KeyboardEvent(string type, bool bubbles = ..., bool cancelable = ..., IWindow view = ..., int detail = ..., string key = ..., KeyboardLocation location = ..., string modifiersList = ..., bool repeat = ...)`
  - `bool GetModifierState(string key)`
  - `void Init(string type, bool bubbles, bool cancelable, IWindow view, int detail, string key, KeyboardLocation location, string modifiersList, bool repeat)`
  - `bool IsAltPressed { get; }`
  - `bool IsCtrlPressed { get; }`
  - `bool IsMetaPressed { get; }`
  - `bool IsRepeated { get; set; }`
  - `bool IsShiftPressed { get; }`
  - `string Key { get; set; }`
  - `string Locale { get; }`
  - `KeyboardLocation Location { get; set; }`

`enum KeyboardLocation`
  - `values: Standard, Left, Right, NumPad`

`enum MouseButton`
  - `values: Primary, Auxiliary, Secondary`

`enum MouseButtons`
  - `values: None, Primary, Secondary, Auxiliary`

`class MouseEvent`
  - `MouseEvent()`
  - `MouseEvent(string type, bool bubbles = ..., bool cancelable = ..., IWindow view = ..., int detail = ..., int screenX = ..., int screenY = ..., int clientX = ..., int clientY = ..., bool ctrlKey = ..., bool altKey = ..., bool shiftKey = ..., bool metaKey = ..., MouseButton button = ..., IEventTarget relatedTarget = ...)`
  - `bool GetModifierState(string key)`
  - `void Init(string type, bool bubbles, bool cancelable, IWindow view, int detail, int screenX, int screenY, int clientX, int clientY, bool ctrlKey, bool altKey, bool shiftKey, bool metaKey, MouseButton button, IEventTarget target)`
  - `MouseButton Button { get; set; }`
  - `MouseButtons Buttons { get; set; }`
  - `int ClientX { get; set; }`
  - `int ClientY { get; set; }`
  - `bool IsAltPressed { get; set; }`
  - `bool IsCtrlPressed { get; set; }`
  - `bool IsMetaPressed { get; set; }`
  - `bool IsShiftPressed { get; set; }`
  - `int ScreenX { get; set; }`
  - `int ScreenY { get; set; }`
  - `IEventTarget Target { get; set; }`

`class TouchEvent`
  - `TouchEvent()`
  - `TouchEvent(string type, bool bubbles = ..., bool cancelable = ..., IWindow view = ..., int detail = ..., ITouchList touches = ..., ITouchList targetTouches = ..., ITouchList changedTouches = ..., bool ctrlKey = ..., bool altKey = ..., bool shiftKey = ..., bool metaKey = ...)`
  - `void Init(string type, bool bubbles, bool cancelable, IWindow view, int detail, ITouchList touches, ITouchList targetTouches, ITouchList changedTouches, bool ctrlKey, bool altKey, bool shiftKey, bool metaKey)`
  - `ITouchList ChangedTouches { get; set; }`
  - `bool IsAltPressed { get; set; }`
  - `bool IsCtrlPressed { get; set; }`
  - `bool IsMetaPressed { get; set; }`
  - `bool IsShiftPressed { get; set; }`
  - `ITouchList TargetTouches { get; set; }`
  - `ITouchList Touches { get; set; }`

`class TrackEvent`
  - `TrackEvent()`
  - `TrackEvent(string type, bool bubbles = ..., bool cancelable = ..., object track = ...)`
  - `void Init(string type, bool bubbles, bool cancelable, object track)`
  - `object Track { get; set; }`

`class WheelEvent`
  - `WheelEvent()`
  - `WheelEvent(string type, bool bubbles = ..., bool cancelable = ..., IWindow view = ..., int detail = ..., int screenX = ..., int screenY = ..., int clientX = ..., int clientY = ..., MouseButton button = ..., IEventTarget target = ..., string modifiersList = ..., double deltaX = ..., double deltaY = ..., double deltaZ = ..., WheelMode deltaMode = ...)`
  - `void Init(string type, bool bubbles, bool cancelable, IWindow view, int detail, int screenX, int screenY, int clientX, int clientY, MouseButton button, IEventTarget target, string modifiersList, double deltaX, double deltaY, double deltaZ, WheelMode deltaMode)`
  - `WheelMode DeltaMode { get; set; }`
  - `double DeltaX { get; set; }`
  - `double DeltaY { get; set; }`
  - `double DeltaZ { get; set; }`

`enum WheelMode`
  - `values: Pixel, Line, Page`

`class FormExtensions`
  - `IHtmlFormElement SetValues(IHtmlFormElement form, IDictionary<string, string> fields, bool createMissing = ...)`
  - `Task<IDocument> SubmitAsync(IHtmlFormElement form, object fields)`
  - `Task<IDocument> SubmitAsync(IHtmlFormElement form, IDictionary<string, string> fields, bool createMissing = ...)`
  - `Task<IDocument> SubmitAsync(IHtmlElement element, object fields = ...)`
  - `Task<IDocument> SubmitAsync(IHtmlElement element, IDictionary<string, string> fields, bool createMissing = ...)`

`class HtmlElement`
  - `HtmlElement(Document owner, string localName, string prefix = ..., NodeFlags flags = ...)`
  - `Node Clone(Document owner, bool deep)`
  - `void DoBlur()`
  - `void DoClick()`
  - `void DoFocus()`
  - `void DoSpellCheck()`
  - `IElement ParseSubtree(string html)`
  - `string AccessKey { get; set; }`
  - `string AccessKeyLabel { get; }`
  - `string ContentEditable { get; set; }`
  - `IHtmlMenuElement ContextMenu { get; set; }`
  - `IStringMap Dataset { get; }`
  - `string Direction { get; set; }`
  - `ISettableTokenList DropZone { get; }`
  - `bool IsContentEditable { get; }`
  - `bool IsDraggable { get; set; }`
  - `bool IsHidden { get; set; }`
  - `bool IsSpellChecked { get; set; }`
  - `bool IsTranslated { get; set; }`
  - `string Language { get; set; }`
  - `int TabIndex { get; set; }`
  - `string Title { get; set; }`

`class HtmlLinkElementExtensions`
  - `bool IsAlternate(IHtmlLinkElement link)`
  - `bool IsPersistent(IHtmlLinkElement link)`
  - `bool IsPreferred(IHtmlLinkElement link)`

`interface IHtmlAnchorElement`
  - `string Download { get; set; }`
  - `ISettableTokenList Ping { get; }`
  - `string Relation { get; set; }`
  - `ITokenList RelationList { get; }`
  - `string Target { get; set; }`
  - `string TargetLanguage { get; set; }`
  - `string Text { get; }`
  - `string Type { get; }`

`interface IHtmlAreaElement`
  - `string AlternativeText { get; set; }`
  - `string Coordinates { get; set; }`
  - `string Download { get; set; }`
  - `ISettableTokenList Ping { get; }`
  - `string Relation { get; set; }`
  - `ITokenList RelationList { get; }`
  - `string Shape { get; set; }`
  - `string Target { get; set; }`
  - `string TargetLanguage { get; set; }`
  - `string Type { get; set; }`

`interface IHtmlBaseElement`
  - `string Href { get; set; }`
  - `string Target { get; set; }`

`interface IHtmlButtonElement`
  - `bool Autofocus { get; set; }`
  - `IHtmlFormElement Form { get; }`
  - `string FormAction { get; set; }`
  - `string FormEncType { get; set; }`
  - `string FormMethod { get; set; }`
  - `bool FormNoValidate { get; set; }`
  - `string FormTarget { get; set; }`
  - `bool IsDisabled { get; set; }`
  - `INodeList Labels { get; }`
  - `string Name { get; set; }`
  - `string Type { get; set; }`
  - `string Value { get; set; }`

`interface IHtmlCanvasElement`
  - `IRenderingContext GetContext(string contextId)`
  - `bool IsSupportingContext(string contextId)`
  - `void SetContext(IRenderingContext context)`
  - `void ToBlob(Action<Stream> callback, string type = ...)`
  - `string ToDataUrl(string type = ...)`
  - `int Height { get; set; }`
  - `int Width { get; set; }`

`interface IHtmlCommandElement`
  - `IHtmlElement Command { get; }`
  - `string Icon { get; set; }`
  - `bool IsChecked { get; set; }`
  - `bool IsDisabled { get; set; }`
  - `string Label { get; set; }`
  - `string RadioGroup { get; set; }`
  - `string Type { get; set; }`

`interface IHtmlDataElement`
  - `string Value { get; set; }`

`interface IHtmlDataListElement`
  - `IHtmlCollection<IHtmlOptionElement> Options { get; }`

`interface IHtmlDetailsElement`
  - `bool IsOpen { get; set; }`

`interface IHtmlDialogElement`
  - `void Close(string returnValue = ...)`
  - `void Show(IElement anchor = ...)`
  - `void ShowModal(IElement anchor = ...)`
  - `bool Open { get; set; }`
  - `string ReturnValue { get; set; }`

`interface IHtmlElement`
  - `void DoBlur()`
  - `void DoClick()`
  - `void DoFocus()`
  - `void DoSpellCheck()`
  - `string AccessKey { get; set; }`
  - `string AccessKeyLabel { get; }`
  - `string ContentEditable { get; set; }`
  - `IHtmlMenuElement ContextMenu { get; set; }`
  - `IStringMap Dataset { get; }`
  - `string Direction { get; set; }`
  - `ISettableTokenList DropZone { get; }`
  - `bool IsContentEditable { get; }`
  - `bool IsDraggable { get; set; }`
  - `bool IsHidden { get; set; }`
  - `bool IsSpellChecked { get; set; }`
  - `bool IsTranslated { get; set; }`
  - `string Language { get; set; }`
  - `int TabIndex { get; set; }`
  - `string Title { get; set; }`

`interface IHtmlEmbedElement`
  - `string DisplayHeight { get; set; }`
  - `string DisplayWidth { get; set; }`
  - `string Source { get; set; }`
  - `string Type { get; set; }`

`interface IHtmlFieldSetElement`
  - `IHtmlFormControlsCollection Elements { get; }`
  - `IHtmlFormElement Form { get; }`
  - `bool IsDisabled { get; set; }`
  - `string Name { get; set; }`
  - `string Type { get; }`

`interface IHtmlFormElement`
  - `bool CheckValidity()`
  - `DocumentRequest GetSubmission()`
  - `DocumentRequest GetSubmission(IHtmlElement sourceElement)`
  - `bool ReportValidity()`
  - `void RequestAutocomplete()`
  - `void Reset()`
  - `Task<IDocument> SubmitAsync()`
  - `Task<IDocument> SubmitAsync(IHtmlElement sourceElement)`
  - `string AcceptCharset { get; set; }`
  - `string Action { get; set; }`
  - `string Autocomplete { get; set; }`
  - `IHtmlFormControlsCollection Elements { get; }`
  - `string Encoding { get; set; }`
  - `string Enctype { get; set; }`
  - `IElement Item { get; }`
  - `IElement Item { get; }`
  - `int Length { get; }`
  - `string Method { get; set; }`
  - `string Name { get; set; }`
  - `bool NoValidate { get; set; }`
  - `string Target { get; set; }`

`interface IHtmlHtmlElement`
  - `string Manifest { get; set; }`

`interface IHtmlImageElement`
  - `string ActualSource { get; }`
  - `string AlternativeText { get; set; }`
  - `string CrossOrigin { get; set; }`
  - `int DisplayHeight { get; set; }`
  - `int DisplayWidth { get; set; }`
  - `bool IsCompleted { get; }`
  - `bool IsMap { get; set; }`
  - `int OriginalHeight { get; }`
  - `int OriginalWidth { get; }`
  - `string Sizes { get; set; }`
  - `string Source { get; set; }`
  - `string SourceSet { get; set; }`
  - `string UseMap { get; set; }`

`interface IHtmlInlineFrameElement`
  - `IDocument ContentDocument { get; }`
  - `string ContentHtml { get; set; }`
  - `IWindow ContentWindow { get; }`
  - `int DisplayHeight { get; set; }`
  - `int DisplayWidth { get; set; }`
  - `bool IsFullscreenAllowed { get; set; }`
  - `bool IsPaymentRequestAllowed { get; set; }`
  - `bool IsSeamless { get; set; }`
  - `string Name { get; set; }`
  - `string ReferrerPolicy { get; set; }`
  - `ISettableTokenList Sandbox { get; }`
  - `string Source { get; set; }`

`interface IHtmlInputElement`
  - `void Select(int selectionStart, int selectionEnd, string selectionDirection = ...)`
  - `void SelectAll()`
  - `void StepDown(int n = ...)`
  - `void StepUp(int n = ...)`
  - `string Accept { get; set; }`
  - `string AlternativeText { get; set; }`
  - `string Autocomplete { get; set; }`
  - `bool Autofocus { get; set; }`
  - `string DefaultValue { get; set; }`
  - `string DirectionName { get; set; }`
  - `int DisplayHeight { get; set; }`
  - `int DisplayWidth { get; set; }`
  - `IFileList Files { get; }`
  - `IHtmlFormElement Form { get; }`
  - `string FormAction { get; set; }`
  - `string FormEncType { get; set; }`
  - `string FormMethod { get; set; }`
  - `bool FormNoValidate { get; set; }`
  - `string FormTarget { get; set; }`
  - `bool HasValue { get; }`
  - `bool IsChecked { get; set; }`
  - `bool IsDefaultChecked { get; set; }`
  - `bool IsDisabled { get; set; }`
  - `bool IsIndeterminate { get; set; }`
  - `bool IsMultiple { get; set; }`
  - `bool IsReadOnly { get; set; }`
  - `bool IsRequired { get; set; }`
  - `INodeList Labels { get; }`
  - `IHtmlDataListElement List { get; }`
  - `int MaxLength { get; set; }`
  - `string Maximum { get; set; }`
  - `int MinLength { get; set; }`
  - `string Minimum { get; set; }`
  - `string Name { get; set; }`
  - `string Pattern { get; set; }`
  - `string Placeholder { get; set; }`
  - `string SelectionDirection { get; }`
  - `int SelectionEnd { get; set; }`
  - `int SelectionStart { get; set; }`
  - `int Size { get; set; }`
  - `string Source { get; set; }`
  - `string Step { get; set; }`
  - `string Type { get; set; }`
  - `string Value { get; set; }`
  - `Nullable<DateTime> ValueAsDate { get; set; }`
  - `double ValueAsNumber { get; set; }`

`interface IHtmlKeygenElement`
  - `bool Autofocus { get; set; }`
  - `string Challenge { get; set; }`
  - `IHtmlFormElement Form { get; }`
  - `bool IsDisabled { get; set; }`
  - `string KeyEncryption { get; set; }`
  - `INodeList Labels { get; }`
  - `string Name { get; set; }`
  - `string Type { get; }`

`interface IHtmlLabelElement`
  - `IHtmlElement Control { get; }`
  - `IHtmlFormElement Form { get; }`
  - `string HtmlFor { get; set; }`

`interface IHtmlLegendElement`
  - `IHtmlFormElement Form { get; }`

`interface IHtmlLinkElement`
  - `string CrossOrigin { get; set; }`
  - `string Href { get; set; }`
  - `string Integrity { get; set; }`
  - `bool IsDisabled { get; set; }`
  - `string Media { get; set; }`
  - `string NumberUsedOnce { get; set; }`
  - `string Relation { get; set; }`
  - `ITokenList RelationList { get; }`
  - `string ReverseRelation { get; set; }`
  - `ISettableTokenList Sizes { get; }`
  - `string TargetLanguage { get; set; }`
  - `string Type { get; set; }`

`interface IHtmlListItemElement`
  - `Nullable<int> Value { get; set; }`

`interface IHtmlMapElement`
  - `IHtmlCollection<IHtmlAreaElement> Areas { get; }`
  - `IHtmlCollection<IHtmlImageElement> Images { get; }`
  - `string Name { get; set; }`

`interface IHtmlMarqueeElement`
  - `int Loop { get; set; }`
  - `int MinimumDelay { get; }`
  - `int ScrollAmount { get; set; }`
  - `int ScrollDelay { get; set; }`

`interface IHtmlMediaElement`
  - `ITextTrack AddTextTrack(string kind, string label = ..., string language = ...)`
  - `string CanPlayType(string type)`
  - `void Load()`
  - `IAudioTrackList AudioTracks { get; }`
  - `IMediaController Controller { get; }`
  - `string CrossOrigin { get; set; }`
  - `string CurrentSource { get; }`
  - `bool IsAutoplay { get; set; }`
  - `bool IsDefaultMuted { get; set; }`
  - `bool IsEnded { get; }`
  - `bool IsLoop { get; set; }`
  - `bool IsSeeking { get; }`
  - `bool IsShowingControls { get; set; }`
  - `IMediaError MediaError { get; }`
  - `string MediaGroup { get; set; }`
  - `MediaNetworkState NetworkState { get; }`
  - `string Preload { get; set; }`
  - `string Source { get; set; }`
  - `DateTime StartDate { get; }`
  - `ITextTrackList TextTracks { get; }`
  - `IVideoTrackList VideoTracks { get; }`

`interface IHtmlMenuElement`
  - `string Label { get; set; }`
  - `string Type { get; set; }`

`interface IHtmlMenuItemElement`
  - `IHtmlElement Command { get; }`
  - `string Icon { get; set; }`
  - `bool IsChecked { get; set; }`
  - `bool IsDefault { get; set; }`
  - `bool IsDisabled { get; set; }`
  - `string Label { get; set; }`
  - `string RadioGroup { get; set; }`
  - `string Type { get; set; }`

`interface IHtmlMetaElement`
  - `string Charset { get; set; }`
  - `string Content { get; set; }`
  - `string HttpEquivalent { get; set; }`
  - `string Name { get; set; }`

`interface IHtmlMeterElement`
  - `double High { get; set; }`
  - `double Low { get; set; }`
  - `double Maximum { get; set; }`
  - `double Minimum { get; set; }`
  - `double Optimum { get; set; }`
  - `double Value { get; set; }`

`interface IHtmlModElement`
  - `string Citation { get; set; }`
  - `string DateTime { get; set; }`

`interface IHtmlObjectElement`
  - `IDocument ContentDocument { get; }`
  - `IWindow ContentWindow { get; }`
  - `int DisplayHeight { get; set; }`
  - `int DisplayWidth { get; set; }`
  - `IHtmlFormElement Form { get; }`
  - `string Name { get; set; }`
  - `string Source { get; set; }`
  - `string Type { get; set; }`
  - `bool TypeMustMatch { get; set; }`
  - `string UseMap { get; set; }`

`interface IHtmlOptionElement`
  - `IHtmlFormElement Form { get; }`
  - `int Index { get; }`
  - `bool IsDefaultSelected { get; set; }`
  - `bool IsDisabled { get; set; }`
  - `bool IsSelected { get; set; }`
  - `string Label { get; set; }`
  - `string Text { get; set; }`
  - `string Value { get; set; }`

`interface IHtmlOptionsCollection`
  - `void Add(IHtmlOptionElement element, IHtmlElement before = ...)`
  - `void Add(IHtmlOptionsGroupElement element, IHtmlElement before = ...)`
  - `IHtmlOptionElement GetOptionAt(int index)`
  - `void Remove(int index)`
  - `void SetOptionAt(int index, IHtmlOptionElement option)`
  - `int SelectedIndex { get; set; }`

`interface IHtmlOptionsGroupElement`
  - `bool IsDisabled { get; set; }`
  - `string Label { get; set; }`

`interface IHtmlOrderedListElement`
  - `bool IsReversed { get; set; }`
  - `int Start { get; set; }`
  - `string Type { get; set; }`

`interface IHtmlOutputElement`
  - `string DefaultValue { get; set; }`
  - `IHtmlFormElement Form { get; }`
  - `ISettableTokenList HtmlFor { get; }`
  - `INodeList Labels { get; }`
  - `string Name { get; set; }`
  - `string Type { get; }`
  - `string Value { get; set; }`

`interface IHtmlParamElement`
  - `string Name { get; set; }`
  - `string Value { get; set; }`

`interface IHtmlProgressElement`
  - `double Maximum { get; set; }`
  - `double Position { get; }`
  - `double Value { get; set; }`

`interface IHtmlQuoteElement`
  - `string Citation { get; set; }`

`interface IHtmlScriptElement`
  - `string CharacterSet { get; set; }`
  - `string CrossOrigin { get; set; }`
  - `string Integrity { get; set; }`
  - `bool IsAsync { get; set; }`
  - `bool IsDeferred { get; set; }`
  - `string Source { get; set; }`
  - `string Text { get; set; }`
  - `string Type { get; set; }`

`interface IHtmlSelectElement`
  - `void AddOption(IHtmlOptionElement element, IHtmlElement before = ...)`
  - `void AddOption(IHtmlOptionsGroupElement element, IHtmlElement before = ...)`
  - `void RemoveOptionAt(int index)`
  - `bool Autofocus { get; set; }`
  - `IHtmlFormElement Form { get; }`
  - `bool IsDisabled { get; set; }`
  - `bool IsMultiple { get; set; }`
  - `bool IsRequired { get; set; }`
  - `IHtmlOptionElement Item { get; set; }`
  - `INodeList Labels { get; }`
  - `int Length { get; }`
  - `string Name { get; set; }`
  - `IHtmlOptionsCollection Options { get; }`
  - `int SelectedIndex { get; }`
  - `IHtmlCollection<IHtmlOptionElement> SelectedOptions { get; }`
  - `int Size { get; set; }`
  - `string Type { get; }`
  - `string Value { get; set; }`

`interface IHtmlSlotElement`
  - `IEnumerable<INode> GetDistributedNodes()`
  - `string Name { get; set; }`

`interface IHtmlSourceElement`
  - `string Media { get; set; }`
  - `string Sizes { get; set; }`
  - `string Source { get; set; }`
  - `string SourceSet { get; set; }`
  - `string Type { get; set; }`

`interface IHtmlStyleElement`
  - `bool IsDisabled { get; set; }`
  - `bool IsScoped { get; set; }`
  - `string Media { get; set; }`
  - `string Type { get; set; }`

`interface IHtmlTableCellElement`
  - `int ColumnSpan { get; set; }`
  - `ISettableTokenList Headers { get; }`
  - `int Index { get; }`
  - `int RowSpan { get; set; }`

`interface IHtmlTableColumnElement`
  - `int Span { get; set; }`

`interface IHtmlTableElement`
  - `IHtmlTableSectionElement CreateBody()`
  - `IHtmlTableCaptionElement CreateCaption()`
  - `IHtmlTableSectionElement CreateFoot()`
  - `IHtmlTableSectionElement CreateHead()`
  - `void DeleteCaption()`
  - `void DeleteFoot()`
  - `void DeleteHead()`
  - `IHtmlTableRowElement InsertRowAt(int index = ...)`
  - `void RemoveRowAt(int index)`
  - `IHtmlCollection<IHtmlTableSectionElement> Bodies { get; }`
  - `UInt32 Border { get; set; }`
  - `IHtmlTableCaptionElement Caption { get; set; }`
  - `IHtmlTableSectionElement Foot { get; set; }`
  - `IHtmlTableSectionElement Head { get; set; }`
  - `IHtmlCollection<IHtmlTableRowElement> Rows { get; }`

`interface IHtmlTableHeaderCellElement`
  - `string Scope { get; set; }`

`interface IHtmlTableRowElement`
  - `IHtmlTableCellElement InsertCellAt(int index = ..., TableCellKind tableCellKind = ...)`
  - `void RemoveCellAt(int index)`
  - `IHtmlCollection<IHtmlTableCellElement> Cells { get; }`
  - `int Index { get; }`
  - `int IndexInSection { get; }`

`interface IHtmlTableSectionElement`
  - `IHtmlTableRowElement InsertRowAt(int index = ...)`
  - `void RemoveRowAt(int index)`
  - `IHtmlCollection<IHtmlTableRowElement> Rows { get; }`

`interface IHtmlTemplateElement`
  - `IDocumentFragment Content { get; }`

`interface IHtmlTextAreaElement`
  - `void Select(int selectionStart, int selectionEnd, string selectionDirection = ...)`
  - `void SelectAll()`
  - `bool Autofocus { get; set; }`
  - `int Columns { get; set; }`
  - `string DefaultValue { get; set; }`
  - `string DirectionName { get; set; }`
  - `IHtmlFormElement Form { get; }`
  - `bool IsDisabled { get; set; }`
  - `bool IsReadOnly { get; set; }`
  - `bool IsRequired { get; set; }`
  - `INodeList Labels { get; }`
  - `int MaxLength { get; set; }`
  - `string Name { get; set; }`
  - `string Placeholder { get; set; }`
  - `int Rows { get; set; }`
  - `string SelectionDirection { get; }`
  - `int SelectionEnd { get; set; }`
  - `int SelectionStart { get; set; }`
  - `int TextLength { get; }`
  - `string Type { get; }`
  - `string Value { get; set; }`
  - `string Wrap { get; set; }`

`interface IHtmlTimeElement`
  - `string DateTime { get; set; }`

`interface IHtmlTitleElement`
  - `string Text { get; set; }`

`interface IHtmlTrackElement`
  - `bool IsDefault { get; set; }`
  - `string Kind { get; set; }`
  - `string Label { get; set; }`
  - `TrackReadyState ReadyState { get; }`
  - `string Source { get; set; }`
  - `string SourceLanguage { get; set; }`
  - `ITextTrack Track { get; }`

`interface IHtmlVideoElement`
  - `int DisplayHeight { get; set; }`
  - `int DisplayWidth { get; set; }`
  - `int OriginalHeight { get; }`
  - `int OriginalWidth { get; }`
  - `string Poster { get; set; }`

`interface ILabelabelElement`
  - `INodeList Labels { get; }`

`interface IValidation`
  - `bool CheckValidity()`
  - `void SetCustomValidity(string error)`
  - `string ValidationMessage { get; }`
  - `IValidityState Validity { get; }`
  - `bool WillValidate { get; }`

`interface IValidityState`
  - `bool IsBadInput { get; }`
  - `bool IsCustomError { get; }`
  - `bool IsPatternMismatch { get; }`
  - `bool IsRangeOverflow { get; }`
  - `bool IsRangeUnderflow { get; }`
  - `bool IsStepMismatch { get; }`
  - `bool IsTooLong { get; }`
  - `bool IsTooShort { get; }`
  - `bool IsTypeMismatch { get; }`
  - `bool IsValid { get; }`
  - `bool IsValueMissing { get; }`

`class ImageExtensions`
  - `Stack<IHtmlSourceElement> GetSources(IHtmlImageElement img)`

`enum TableCellKind`
  - `values: Td, Th`

`enum TableFrames`
  - `values: Void, Box, Above, Below, HSides, VSides, LHS, RHS, Border`

`enum TableRules`
  - `values: None, Rows, Cols, Groups, All`

`enum TrackReadyState`
  - `values: None, Loading, Loaded, Error`

`class FormDataSet`
  - `FormDataSet()`
  - `void Append(string name, string value, string type)`
  - `void Append(string name, IFile value, string type)`
  - `Stream As(IFormSubmitter submitter, Encoding encoding = ...)`
  - `Stream AsJson()`
  - `Stream AsMultipart(IHtmlEncoder htmlEncoder, Encoding encoding = ...)`
  - `Stream AsPlaintext(Encoding encoding = ...)`
  - `Stream AsUrlEncoded(Encoding encoding = ...)`
  - `IEnumerator<string> GetEnumerator()`
  - `string Boundary { get; }`

`class FormDataSetEntry`
  - `FormDataSetEntry(string name, string type)`
  - `void Accept(IFormDataSetVisitor visitor)`
  - `bool Contains(string boundary, Encoding encoding)`
  - `bool HasName { get; }`
  - `string Name { get; }`
  - `string Type { get; }`

`interface IFormDataSetVisitor`
  - `void File(FormDataSetEntry entry, string fileName, string contentType, IFile content)`
  - `void Text(FormDataSetEntry entry, string value)`

`interface IFormSubmitter`
  - `void Serialize(StreamWriter stream)`

`class DefaultHtmlEncoder`
  - `DefaultHtmlEncoder()`
  - `string Encode(string value, Encoding encoding)`

`interface IHtmlEncoder`
  - `string Encode(string value, Encoding encoding)`

`class HtmlEntityProvider`
  - `string GetName(string symbol)`
  - `string GetSymbol(string name)`
  - `string GetSymbol(StringOrMemory name)`
  - `string GetSymbolFromTable(int code)`
  - `bool IsInCharacterTable(int code)`
  - `bool IsInInvalidRange(int code)`
  - `bool IsInvalidNumber(int code)`
  - `IReverseEntityProvider ReverseResolver { get; }`

`class HtmlMarkupFormatter`
  - `HtmlMarkupFormatter()`
  - `string CloseTag(IElement element, bool selfClosing)`
  - `string Comment(IComment comment)`
  - `string Doctype(IDocumentType doctype)`
  - `string EscapeText(string content)`
  - `string GetIds(string publicId, string systemId)`
  - `string LiteralText(ICharacterData text)`
  - `string OpenTag(IElement element, bool selfClosing)`
  - `string Processing(IProcessingInstruction processing)`
  - `string Text(ICharacterData text)`
  - `string XmlNamespaceLocalName(string name)`

`interface IInputTypeFactory`
  - `BaseInputType Create(IHtmlInputElement input, string type)`

`interface ILinkRelationFactory`
  - `BaseLinkRelation Create(IHtmlLinkElement link, string relation)`

`class BaseInputType`
  - `BaseInputType(IHtmlInputElement input, string name, bool validate)`
  - `ValidationErrors Check(IValidityState current)`
  - `void ConstructDataSet(FormDataSet dataSet)`
  - `string ConvertFromDate(DateTime value)`
  - `string ConvertFromNumber(double value)`
  - `Nullable<DateTime> ConvertToDate(string value)`
  - `Nullable<double> ConvertToNumber(string value)`
  - `void DoStep(int n)`
  - `bool IsAppendingData(IHtmlElement submitter)`
  - `bool CanBeValidated { get; }`
  - `IHtmlInputElement Input { get; }`
  - `string Name { get; }`

`class BaseLinkRelation`
  - `BaseLinkRelation(IHtmlLinkElement link, IRequestProcessor processor)`
  - `Task LoadAsync()`
  - `IHtmlLinkElement Link { get; }`
  - `IRequestProcessor Processor { get; }`
  - `Url Url { get; }`

`class MinifyMarkupFormatter`
  - `MinifyMarkupFormatter()`
  - `string CloseTag(IElement element, bool selfClosing)`
  - `string Comment(IComment comment)`
  - `string OpenTag(IElement element, bool selfClosing)`
  - `string Text(ICharacterData text)`
  - `IEnumerable<string> PreservedTags { get; set; }`
  - `bool ShouldKeepAttributeQuotes { get; set; }`
  - `bool ShouldKeepComments { get; set; }`
  - `bool ShouldKeepEmptyAttributes { get; set; }`
  - `bool ShouldKeepImpliedEndTag { get; set; }`
  - `bool ShouldKeepStandardElements { get; set; }`

`enum HtmlParseError`
  - `values: EOF, Null, BogusComment, AmbiguousOpenTag, TagClosedWrong, ClosingSlashMisplaced, UndefinedMarkupDeclaration, CommentEndedWithEM, CommentEndedWithDash, CommentEndedUnexpected, TagCannotBeSelfClosed, EndTagCannotBeSelfClosed, EndTagCannotHaveAttributes, CaptionNotInScope, SelectNotInScope, TableRowNotInScope, TableNotInScope, ParagraphNotInScope, BodyNotInScope, BlockNotInScope, TableCellNotInScope, TableSectionNotInScope, ObjectNotInScope, HeadingNotInScope, ListItemNotInScope, FormNotInScope, ButtonInScope, NobrInScope, ElementNotInScope, CharacterReferenceWrongNumber, CharacterReferenceSemicolonMissing, CharacterReferenceInvalidRange, CharacterReferenceInvalidNumber, CharacterReferenceInvalidCode, CharacterReferenceNotTerminated, CharacterReferenceAttributeEqualsFound, ItemNotFound, EncodingError, DoctypeUnexpectedAfterName, DoctypePublicInvalid, DoctypeInvalidCharacter, DoctypeSystemInvalid, DoctypeTagInappropriate, DoctypeInvalid, DoctypeUnexpected, DoctypeMissing, NotationPublicInvalid, NotationSystemInvalid, TypeDeclarationUndefined, QuantifierMissing, DoubleQuotationMarkUnexpected, SingleQuotationMarkUnexpected, AttributeNameInvalid, AttributeValueInvalid, AttributeNameExpected, AttributeDuplicateOmitted, TagMustBeInHead, TagInappropriate, TagCannotEndHere, TagCannotStartHere, FormInappropriate, InputUnexpected, TagClosingMismatch, TagDoesNotMatchCurrentNode, LineBreakUnexpected, HeadTagMisplaced, HtmlTagMisplaced, BodyTagMisplaced, ImageTagNamedWrong, TableNesting, IllegalElementInTableDetected, SelectNesting, IllegalElementInSelectDetected, FramesetMisplaced, HeadingNested, AnchorNested, TokenNotPossible, CurrentNodeIsNotRoot, CurrentNodeIsRoot, TagInvalidInFragmentMode, FormAlreadyOpen, FormClosedWrong, BodyClosedWrong, FormattingElementNotFound`

`class HtmlParseException`
  - `HtmlParseException(int code, string message, TextPosition position)`
  - `int Code { get; }`
  - `TextPosition Position { get; }`

`enum HtmlParseMode`
  - `values: PCData, RCData, Plaintext, Rawtext, Script`

`class HtmlParser`
  - `HtmlParser()`
  - `HtmlParser(HtmlParserOptions options)`
  - `HtmlParser(HtmlParserOptions options, IBrowsingContext context)`
  - `IHtmlDocument ParseDocument(string source)`
  - `IHtmlDocument ParseDocument(Stream source)`
  - `IHtmlDocument ParseDocument(char[] source, int length = ...)`
  - `IHtmlDocument ParseDocument(ReadOnlyMemory<char> chars)`
  - `IHtmlDocument ParseDocument(TextSource source)`
  - `TDocument ParseDocument<TDocument, TElement>(TextSource source, TokenizerMiddleware middleware = ...)`
  - `Task<IHtmlDocument> ParseDocumentAsync(string source, CancellationToken cancel)`
  - `Task<IHtmlDocument> ParseDocumentAsync(Stream source, CancellationToken cancel)`
  - `INodeList ParseFragment(Stream source, IElement contextElement)`
  - `INodeList ParseFragment(string source, IElement contextElement)`
  - `IHtmlHeadElement ParseHead(string source)`
  - `IHtmlHeadElement ParseHead(Stream source)`
  - `Task<IHtmlHeadElement> ParseHeadAsync(string source, CancellationToken cancel)`
  - `Task<IHtmlHeadElement> ParseHeadAsync(Stream source, CancellationToken cancel)`
  - `HtmlParserOptions Options { get; }`

`class HtmlParserExtensions`
  - `Task<IHtmlDocument> ParseDocumentAsync(IHtmlParser parser, string source)`
  - `Task<IHtmlDocument> ParseDocumentAsync(IHtmlParser parser, Stream source)`
  - `Task<IDocument> ParseDocumentAsync(IHtmlParser parser, IDocument document)`
  - `Task<IHtmlHeadElement> ParseHeadAsync(IHtmlParser parser, string source)`
  - `Task<IHtmlHeadElement> ParseHeadAsync(IHtmlParser parser, Stream source)`

`struct HtmlParserOptions`
  - `bool DisableElementPositionTracking { get; set; }`
  - `bool IsAcceptingCustomElementsEverywhere { get; set; }`
  - `bool IsEmbedded { get; set; }`
  - `bool IsKeepingSourceReferences { get; set; }`
  - `bool IsNotConsumingCharacterReferences { get; set; }`
  - `bool IsNotSupportingFrames { get; set; }`
  - `bool IsPreservingAttributeNames { get; set; }`
  - `bool IsScripting { get; set; }`
  - `bool IsStrictMode { get; set; }`
  - `bool IsSupportingProcessingInstructions { get; set; }`
  - `Action<IElement, TextPosition> OnCreated { get; set; }`
  - `Action<HtmlToken, TextRange> OnToken { get; set; }`
  - `ShouldEmitAttribute ShouldEmitAttribute { get; set; }`
  - `bool SkipCDATA { get; set; }`
  - `bool SkipComments { get; set; }`
  - `bool SkipDataText { get; set; }`
  - `bool SkipPlaintext { get; set; }`
  - `bool SkipProcessingInstructions { get; set; }`
  - `bool SkipRCDataText { get; set; }`
  - `bool SkipRawText { get; set; }`
  - `bool SkipScriptText { get; set; }`

`enum HtmlTokenType`
  - `values: Doctype, StartTag, EndTag, Comment, Character, EndOfFile`

`class HtmlTokenizer`
  - `HtmlTokenizer(TextSource source, IEntityProvider resolver)`
  - `HtmlTokenizer(TextSource source, IEntityProviderExtended resolver)`
  - `HtmlToken Get()`
  - `StructHtmlToken GetStructToken()`
  - `bool IsAcceptingCharacterData { get; set; }`
  - `bool IsNotConsumingCharacterReferences { get; set; }`
  - `bool IsPreservingAttributeNames { get; set; }`
  - `bool IsStrictMode { get; set; }`
  - `bool IsSupportingProcessingInstructions { get; set; }`
  - `Action<HtmlToken, TextRange> OnToken { get; set; }`
  - `ShouldEmitAttribute ShouldEmitAttribute { get; set; }`
  - `bool SkipCDATA { get; set; }`
  - `bool SkipComments { get; set; }`
  - `bool SkipDataText { get; set; }`
  - `bool SkipPlaintext { get; set; }`
  - `bool SkipProcessingInstructions { get; set; }`
  - `bool SkipRCDataText { get; set; }`
  - `bool SkipRawText { get; set; }`
  - `bool SkipScriptText { get; set; }`
  - `HtmlParseMode State { get; set; }`

`struct HtmlTokenizerOptions`
  - `HtmlTokenizerOptions(HtmlParserOptions htmlParserOptions)`
  - `bool DisableElementPositionTracking { get; set; }`
  - `bool IsNotConsumingCharacterReferences { get; set; }`
  - `bool IsPreservingAttributeNames { get; set; }`
  - `bool IsStrictMode { get; set; }`
  - `bool IsSupportingProcessingInstructions { get; set; }`
  - `ShouldEmitAttribute ShouldEmitAttribute { get; set; }`
  - `bool SkipCDATA { get; set; }`
  - `bool SkipComments { get; set; }`
  - `bool SkipDataText { get; set; }`
  - `bool SkipPlaintext { get; set; }`
  - `bool SkipProcessingInstructions { get; set; }`
  - `bool SkipRCDataText { get; set; }`
  - `bool SkipRawText { get; set; }`
  - `bool SkipScriptText { get; set; }`

`interface IHtmlParser`
  - `IHtmlDocument ParseDocument(string source)`
  - `IHtmlDocument ParseDocument(Stream source)`
  - `IHtmlDocument ParseDocument(char[] source, int length = ...)`
  - `IHtmlDocument ParseDocument(TextSource source)`
  - `IHtmlDocument ParseDocument(ReadOnlyMemory<char> chars)`
  - `TDocument ParseDocument<TDocument, TElement>(TextSource source, TokenizerMiddleware middleware = ...)`
  - `Task<IHtmlDocument> ParseDocumentAsync(string source, CancellationToken cancel)`
  - `Task<IHtmlDocument> ParseDocumentAsync(Stream source, CancellationToken cancel)`
  - `Task<IDocument> ParseDocumentAsync(IDocument document, CancellationToken cancel)`
  - `INodeList ParseFragment(string source, IElement contextElement)`
  - `INodeList ParseFragment(Stream source, IElement contextElement)`
  - `IHtmlHeadElement ParseHead(string source)`
  - `IHtmlHeadElement ParseHead(Stream source)`
  - `Task<IHtmlHeadElement> ParseHeadAsync(string source, CancellationToken cancel)`
  - `Task<IHtmlHeadElement> ParseHeadAsync(Stream source, CancellationToken cancel)`

`class ShouldEmitAttribute`
  - `ShouldEmitAttribute(object object, IntPtr method)`
  - `IAsyncResult BeginInvoke(StructHtmlToken token, ReadOnlyMemory<char> attributeName, AsyncCallback callback, object object)`
  - `bool EndInvoke(StructHtmlToken token, IAsyncResult result)`
  - `bool Invoke(StructHtmlToken token, ReadOnlyMemory<char> attributeName)`

`class TokenConsumer`
  - `TokenConsumer(object object, IntPtr method)`
  - `IAsyncResult BeginInvoke(StructHtmlToken token, AsyncCallback callback, object object)`
  - `void EndInvoke(StructHtmlToken token, IAsyncResult result)`
  - `void Invoke(StructHtmlToken token)`

`enum TokenConsumptionResult`
  - `values: Continue, Stop`

`class TokenizerExtensions`
  - `IEnumerable<HtmlToken> Tokenize(TextSource source, IEntityProvider provider = ..., EventHandler<HtmlErrorEvent> errorHandler = ...)`
  - `IEnumerable<HtmlToken> Tokenize(TextSource source, Nullable<HtmlTokenizerOptions> options = ..., IEntityProvider provider = ..., EventHandler<HtmlErrorEvent> errorHandler = ...)`

`class TokenizerMiddleware`
  - `TokenizerMiddleware(object object, IntPtr method)`
  - `IAsyncResult BeginInvoke(StructHtmlToken token, TokenConsumer next, AsyncCallback callback, object object)`
  - `TokenConsumptionResult EndInvoke(StructHtmlToken token, IAsyncResult result)`
  - `TokenConsumptionResult Invoke(StructHtmlToken token, TokenConsumer next)`

`struct HtmlAttributeToken`
  - `HtmlAttributeToken(TextPosition position, string name, string value)`
  - `string Name { get; }`
  - `TextPosition Position { get; }`
  - `string Value { get; }`

`class HtmlDoctypeToken`
  - `HtmlDoctypeToken(bool quirksForced, TextPosition position)`
  - `bool IsFullQuirks { get; }`
  - `bool IsLimitedQuirks { get; }`
  - `bool IsPublicIdentifierMissing { get; }`
  - `bool IsQuirksForced { get; set; }`
  - `bool IsSystemIdentifierMissing { get; }`
  - `bool IsValid { get; }`
  - `string PublicIdentifier { get; set; }`
  - `string SystemIdentifier { get; set; }`

`class HtmlTagToken`
  - `HtmlTagToken(HtmlTokenType type, TextPosition position)`
  - `HtmlTagToken(HtmlTokenType type, TextPosition position, string name)`
  - `void AddAttribute(string name, TextPosition position)`
  - `void AddAttribute(string name, string value)`
  - `HtmlTagToken Close(string name)`
  - `string GetAttribute(string name)`
  - `HtmlTagToken Open(string name)`
  - `void SetAttributeValue(string value)`
  - `List<HtmlAttributeToken> Attributes { get; }`
  - `bool IsSelfClosing { get; set; }`

`class HtmlToken`
  - `HtmlToken(HtmlTokenType type, TextPosition position, string name = ...)`
  - `HtmlTagToken AsTag()`
  - `bool IsStartTag(string name)`
  - `void RemoveNewLine()`
  - `string TrimStart()`
  - `string Data { get; }`
  - `bool HasContent { get; }`
  - `bool IsEmpty { get; }`
  - `bool IsHtmlCompatible { get; }`
  - `bool IsMathCompatible { get; }`
  - `bool IsProcessingInstruction { get; set; }`
  - `bool IsSvg { get; }`
  - `string Name { get; set; }`
  - `TextPosition Position { get; }`
  - `HtmlTokenType Type { get; }`

`struct MemoryHtmlAttributeToken`
  - `MemoryHtmlAttributeToken(TextPosition position, StringOrMemory name, StringOrMemory value)`
  - `StringOrMemory Name { get; }`
  - `TextPosition Position { get; }`
  - `StringOrMemory Value { get; }`

`struct StructAttributes`
  - `void Add(MemoryHtmlAttributeToken item)`
  - `bool HasAttribute(StringOrMemory name, StringOrMemory value)`
  - `void RemoveAt(int index)`
  - `int Count { get; }`
  - `MemoryHtmlAttributeToken Item { get; set; }`

`struct StructHtmlToken`
  - `void AddAttribute(StringOrMemory name, TextPosition position)`
  - `void AddAttribute(StringOrMemory name, StringOrMemory value)`
  - `void CleanStart()`
  - `StringOrMemory GetAttribute(StringOrMemory name)`
  - `bool IsStartTag(string name)`
  - `void RemoveAttributeAt(int i)`
  - `void RemoveNewLine()`
  - `void SetAttributeValue(StringOrMemory value)`
  - `HtmlToken ToHtmlToken()`
  - `StringOrMemory TrimStart()`
  - `StructAttributes Attributes { get; }`
  - `StringOrMemory Data { get; }`
  - `bool HasContent { get; }`
  - `bool IsDoctype { get; }`
  - `bool IsEmpty { get; }`
  - `bool IsFullQuirks { get; }`
  - `bool IsHtmlCompatible { get; }`
  - `bool IsLimitedQuirks { get; }`
  - `bool IsMathCompatible { get; }`
  - `bool IsProcessingInstruction { get; set; }`
  - `bool IsPublicIdentifierMissing { get; }`
  - `bool IsQuirksForced { get; set; }`
  - `bool IsSelfClosing { get; set; }`
  - `bool IsSvg { get; }`
  - `bool IsSystemIdentifierMissing { get; }`
  - `bool IsTag { get; }`
  - `bool IsValid { get; }`
  - `StringOrMemory Name { get; set; }`
  - `TextPosition Position { get; }`
  - `StringOrMemory PublicIdentifier { get; set; }`
  - `StringOrMemory SystemIdentifier { get; set; }`
  - `HtmlTokenType Type { get; }`

`class PrettyMarkupFormatter`
  - `PrettyMarkupFormatter()`
  - `PrettyMarkupFormatter(IEnumerable<INode> preserveTextFormatting)`
  - `string CloseTag(IElement element, bool selfClosing)`
  - `string Comment(IComment comment)`
  - `string Doctype(IDocumentType doctype)`
  - `string OpenTag(IElement element, bool selfClosing)`
  - `string Processing(IProcessingInstruction processing)`
  - `string Text(ICharacterData text)`
  - `string Indentation { get; set; }`
  - `string NewLine { get; set; }`

`class SourceSet`
  - `SourceSet()`
  - `IEnumerable<string> GetCandidates(string srcset, string sizes)`
  - `IEnumerable<ImageCandidate> Parse(string srcset)`

`enum ValidationErrors`
  - `values: None, ValueMissing, TypeMismatch, PatternMismatch, TooLong, TooShort, RangeUnderflow, RangeOverflow, StepMismatch, BadInput, Custom`

`interface IBrowsingContext`
  - `IBrowsingContext CreateChild(string name, Sandboxes security)`
  - `IBrowsingContext FindChild(string name)`
  - `T GetService<T>()`
  - `IEnumerable<T> GetServices<T>()`
  - `IDocument Active { get; set; }`
  - `IDocument Creator { get; }`
  - `IWindow Current { get; }`
  - `IEnumerable<object> OriginalServices { get; }`
  - `IBrowsingContext Parent { get; }`
  - `Sandboxes Security { get; }`
  - `IHistory SessionHistory { get; }`

`interface IConfiguration`
  - `IEnumerable<object> Services { get; }`

`interface IMarkupFormattable`
  - `void ToHtml(TextWriter writer, IMarkupFormatter formatter)`

`interface IMarkupFormatter`
  - `string CloseTag(IElement element, bool selfClosing)`
  - `string Comment(IComment comment)`
  - `string Doctype(IDocumentType doctype)`
  - `string LiteralText(ICharacterData text)`
  - `string OpenTag(IElement element, bool selfClosing)`
  - `string Processing(IProcessingInstruction processing)`
  - `string Text(ICharacterData text)`

`interface IStyleFormattable`
  - `void ToCss(TextWriter writer, IStyleFormatter formatter)`

`interface IStyleFormatter`
  - `string BlockDeclarations(IEnumerable<IStyleFormattable> declarations)`
  - `string BlockRules(IEnumerable<IStyleFormattable> rules)`
  - `string Comment(string data)`
  - `string Declaration(string name, string value, bool important)`
  - `string Rule(string name, string value)`
  - `string Rule(string name, string prelude, string rules)`
  - `string Sheet(IEnumerable<IStyleFormattable> rules)`

`class BaseLoader`
  - `BaseLoader(IBrowsingContext context, Predicate<Request> filter)`
  - `IEnumerable<IDownload> GetDownloads()`
  - `int MaxRedirects { get; set; }`

`class BaseRequester`
  - `Task<IResponse> RequestAsync(Request request, CancellationToken cancel)`
  - `bool SupportsProtocol(string protocol)`

`class CorsRequest`
  - `CorsRequest(ResourceRequest request)`
  - `OriginBehavior Behavior { get; set; }`
  - `IIntegrityProvider Integrity { get; set; }`
  - `ResourceRequest Request { get; }`
  - `CorsSetting Setting { get; set; }`

`enum CorsSetting`
  - `values: None, Anonymous, UseCredentials`

`class DefaultDocumentLoader`
  - `DefaultDocumentLoader(IBrowsingContext context, Predicate<Request> filter = ...)`
  - `IDownload FetchAsync(DocumentRequest request)`

`class DefaultHttpRequester`
  - `DefaultHttpRequester(string userAgent = ..., Action<HttpWebRequest> setup = ...)`
  - `bool SupportsProtocol(string protocol)`
  - `IDictionary<string, string> Headers { get; }`
  - `TimeSpan Timeout { get; set; }`

`class DefaultResourceLoader`
  - `DefaultResourceLoader(IBrowsingContext context, Predicate<Request> filter = ...)`
  - `IDownload FetchAsync(ResourceRequest request)`

`class DefaultResponse`
  - `DefaultResponse()`
  - `Url Address { get; set; }`
  - `Stream Content { get; set; }`
  - `IDictionary<string, string> Headers { get; set; }`
  - `HttpStatusCode StatusCode { get; set; }`

`class DocumentRequest`
  - `DocumentRequest(Url target)`
  - `DocumentRequest Get(Url target, INode source = ..., string referer = ...)`
  - `DocumentRequest Post(Url target, Stream body, string type, INode source = ..., string referer = ...)`
  - `DocumentRequest PostAsMultipart(Url target, FormDataSet form)`
  - `DocumentRequest PostAsMultipart(Url target, Stream formBody, string formBoundary)`
  - `DocumentRequest PostAsPlaintext(Url target, IDictionary<string, string> fields)`
  - `DocumentRequest PostAsUrlencoded(Url target, IDictionary<string, string> fields)`
  - `Stream Body { get; set; }`
  - `Dictionary<string, string> Headers { get; }`
  - `HttpMethod Method { get; set; }`
  - `string MimeType { get; set; }`
  - `string Referer { get; set; }`
  - `INode Source { get; set; }`
  - `Url Target { get; }`

`interface IBlob`
  - `void Close()`
  - `IBlob Slice(int start = ..., int end = ..., string contentType = ...)`
  - `Stream Body { get; }`
  - `bool IsClosed { get; }`
  - `int Length { get; }`
  - `string Type { get; }`

`interface IFile`
  - `DateTime LastModified { get; }`
  - `string Name { get; }`

`interface IFileList`
  - `void Add(IFile file)`
  - `void Clear()`
  - `bool Remove(IFile file)`
  - `IFile Item { get; }`
  - `int Length { get; }`

`enum HttpMethod`
  - `values: Get, Post, Put, Delete, Options, Head, Trace, Connect`

`interface ICookieProvider`
  - `string GetCookie(Url url)`
  - `void SetCookie(Url url, string value)`

`interface IDocumentLoader`
  - `IDownload FetchAsync(DocumentRequest request)`

`interface IDownload`
  - `object Source { get; }`
  - `Url Target { get; }`

`interface IIntegrityProvider`
  - `bool IsSatisfied(byte[] content, string integrity)`

`interface ILoadableElement`
  - `IDownload CurrentDownload { get; }`

`interface ILoader`
  - `IEnumerable<IDownload> GetDownloads()`

`interface IRequester`
  - `Task<IResponse> RequestAsync(Request request, CancellationToken cancel)`
  - `bool SupportsProtocol(string protocol)`

`interface IResourceLoader`
  - `IDownload FetchAsync(ResourceRequest request)`

`interface IResponse`
  - `Url Address { get; }`
  - `Stream Content { get; }`
  - `IDictionary<string, string> Headers { get; }`
  - `HttpStatusCode StatusCode { get; }`

`class LoaderOptions`
  - `LoaderOptions()`
  - `Predicate<Request> Filter { get; set; }`
  - `bool IsNavigationDisabled { get; set; }`
  - `bool IsResourceLoadingEnabled { get; set; }`

`class MemoryCookieProvider`
  - `MemoryCookieProvider()`
  - `MemoryCookieProvider(CookieContainer container)`
  - `string GetCookie(Url url)`
  - `void SetCookie(Url url, string value)`
  - `CookieContainer Container { get; }`

`class MimeType`
  - `MimeType(string value)`
  - `bool Equals(MimeType other)`
  - `bool Equals(object obj)`
  - `int GetHashCode()`
  - `string GetParameter(string key)`
  - `string ToString()`
  - `string Content { get; }`
  - `string GeneralType { get; }`
  - `IEnumerable<string> Keys { get; }`
  - `string MediaType { get; }`
  - `string Suffix { get; }`

`class MimeTypeNames`
  - `string FromExtension(string extension)`
  - `string GetExtension(string mimeType)`
  - `bool IsJavaScript(string type)`
  - `bool Represents(MimeType type, string content)`

`enum OriginBehavior`
  - `values: Taint, Fail`

`class BaseRequestProcessor`
  - `BaseRequestProcessor(IResourceLoader loader)`
  - `Task ProcessAsync(ResourceRequest request)`
  - `IDownload Download { get; set; }`
  - `bool IsAvailable { get; }`

`interface IRequestProcessor`
  - `Task ProcessAsync(ResourceRequest request)`
  - `IDownload Download { get; }`

`class ProtocolNames`
  - `bool IsOriginable(string protocol)`
  - `bool IsRelative(string protocol)`

`class Request`
  - `Request()`
  - `Url Address { get; set; }`
  - `Stream Content { get; set; }`
  - `IDictionary<string, string> Headers { get; set; }`
  - `HttpMethod Method { get; set; }`

`class RequesterExtensions`
  - `IDownload FetchWithCorsAsync(IResourceLoader loader, CorsRequest cors)`
  - `bool IsRedirected(HttpStatusCode status)`

`class ResourceRequest`
  - `ResourceRequest(IElement source, Url target)`
  - `bool IsCookieBlocked { get; set; }`
  - `bool IsCredentialOmitted { get; set; }`
  - `bool IsManualRedirectDesired { get; set; }`
  - `bool IsSameOriginForced { get; set; }`
  - `string Origin { get; set; }`
  - `IElement Source { get; }`
  - `Url Target { get; }`

`class ResponseExtensions`
  - `MimeType GetContentType(IResponse response)`
  - `MimeType GetContentType(IResponse response, string defaultType)`

`class VirtualResponse`
  - `VirtualResponse Address(Url url)`
  - `VirtualResponse Address(string address)`
  - `VirtualResponse Address(Uri url)`
  - `VirtualResponse Content(string text)`
  - `VirtualResponse Content(Stream stream, bool shouldDispose = ...)`
  - `VirtualResponse Cookie(string value)`
  - `IResponse Create(Action<VirtualResponse> request)`
  - `VirtualResponse Header(string name, string value)`
  - `VirtualResponse Headers(object obj)`
  - `VirtualResponse Headers(IDictionary<string, string> headers)`
  - `VirtualResponse Status(HttpStatusCode code)`
  - `VirtualResponse Status(int code)`

`class MathElement`
  - `MathElement(Document owner, string name, string prefix = ..., NodeFlags flags = ...)`
  - `Node Clone(Document owner, bool deep)`
  - `IElement ParseSubtree(string html)`

`interface IAudioTrack`
  - `string Id { get; }`
  - `bool IsEnabled { get; set; }`
  - `string Kind { get; }`
  - `string Label { get; }`
  - `string Language { get; }`

`interface IAudioTrackList`
  - `IAudioTrack GetTrackById(string id)`
  - `IAudioTrack Item { get; }`
  - `int Length { get; }`

`interface ICanvasRenderingContext2D`
  - `void RestoreState()`
  - `void SaveState()`
  - `IHtmlCanvasElement Canvas { get; }`
  - `int Height { get; set; }`
  - `int Width { get; set; }`

`interface IMediaController`
  - `void Pause()`
  - `void Play()`
  - `ITimeRanges BufferedTime { get; }`
  - `double CurrentTime { get; set; }`
  - `double DefaultPlaybackRate { get; set; }`
  - `double Duration { get; }`
  - `bool IsMuted { get; set; }`
  - `bool IsPaused { get; }`
  - `double PlaybackRate { get; set; }`
  - `MediaControllerPlaybackState PlaybackState { get; }`
  - `ITimeRanges PlayedTime { get; }`
  - `MediaReadyState ReadyState { get; }`
  - `ITimeRanges SeekableTime { get; }`
  - `double Volume { get; set; }`

`interface IMediaError`
  - `MediaErrorCode Code { get; }`

`interface IRenderingContext`
  - `byte[] ToImage(string type)`
  - `string ContextId { get; }`
  - `IHtmlCanvasElement Host { get; }`
  - `bool IsFixed { get; }`

`interface IRenderingService`
  - `IRenderingContext CreateContext(IHtmlCanvasElement host, string contextId)`
  - `bool IsSupportingContext(string contextId)`

`interface ITextTrack`
  - `void Add(ITextTrackCue cue)`
  - `void Remove(ITextTrackCue cue)`
  - `ITextTrackCueList ActiveCues { get; }`
  - `ITextTrackCueList Cues { get; }`
  - `string Kind { get; }`
  - `string Label { get; }`
  - `string Language { get; }`
  - `TextTrackMode Mode { get; set; }`

`interface ITextTrackCue`
  - `IDocumentFragment AsHtml()`
  - `string Alignment { get; set; }`
  - `double EndTime { get; set; }`
  - `DomEventHandler Entered { get; set; }`
  - `DomEventHandler Exited { get; set; }`
  - `string Id { get; set; }`
  - `bool IsPausedOnExit { get; set; }`
  - `bool IsSnappedToLines { get; set; }`
  - `int Line { get; set; }`
  - `int Position { get; set; }`
  - `int Size { get; set; }`
  - `double StartTime { get; set; }`
  - `string Text { get; set; }`
  - `ITextTrack Track { get; }`
  - `string Vertical { get; set; }`

`interface ITextTrackCueList`
  - `IVideoTrack GetCueById(string id)`
  - `ITextTrackCue Item { get; }`
  - `int Length { get; }`

`interface ITextTrackList`
  - `ITextTrack Item { get; }`
  - `int Length { get; }`

`interface ITimeRanges`
  - `double End(int index)`
  - `double Start(int index)`
  - `int Length { get; }`

`interface IVideoTrack`
  - `string Id { get; }`
  - `bool IsSelected { get; set; }`
  - `string Kind { get; }`
  - `string Label { get; }`
  - `string Language { get; }`

`interface IVideoTrackList`
  - `IVideoTrack GetTrackById(string id)`
  - `IVideoTrack Item { get; }`
  - `int Length { get; }`
  - `int SelectedIndex { get; }`

`enum MediaControllerPlaybackState`
  - `values: Waiting, Playing, Ended`

`enum MediaErrorCode`
  - `values: Aborted, Network, Decode, SourceNotSupported`

`enum MediaNetworkState`
  - `values: Empty, Idle, Loading, NoSource`

`enum MediaReadyState`
  - `values: Nothing, Metadata, CurrentData, FutureData, EnoughData`

`enum TextTrackMode`
  - `values: Disabled, Hidden, Showing`

`interface IImageInfo`
  - `int Height { get; }`
  - `int Width { get; }`

`interface IMediaInfo`
  - `IMediaController Controller { get; }`

`interface IObjectInfo`
  - `int Height { get; }`
  - `int Width { get; }`

`interface IResourceInfo`
  - `Url Source { get; set; }`

`interface IResourceService<TResource>`
  - `Task<TResource> CreateAsync(IResponse response, CancellationToken cancel)`
  - `bool SupportsType(string mimeType)`

`interface IVideoInfo`
  - `int Height { get; }`
  - `int Width { get; }`

`interface IScriptingService`
  - `Task EvaluateScriptAsync(IResponse response, ScriptOptions options, CancellationToken cancel)`
  - `bool SupportsType(string mimeType)`

`class ScriptOptions`
  - `ScriptOptions(IDocument document, IEventLoop loop)`
  - `IDocument Document { get; }`
  - `IHtmlScriptElement Element { get; set; }`
  - `Encoding Encoding { get; set; }`
  - `IEventLoop EventLoop { get; }`

`interface ISvgStyleElement`
  - `bool IsDisabled { get; set; }`
  - `string Media { get; set; }`
  - `string Type { get; set; }`

`class SvgElement`
  - `SvgElement(Document owner, string name, string prefix = ..., NodeFlags flags = ...)`
  - `Node Clone(Document owner, bool deep)`
  - `IElement ParseSubtree(string html)`

`class CharArrayTextSource`
  - `CharArrayTextSource(char[] array, int length)`
  - `void Dispose()`
  - `Task PrefetchAllAsync(CancellationToken cancellationToken)`
  - `Task PrefetchAsync(int length, CancellationToken cancellationToken)`
  - `char ReadCharacter()`
  - `string ReadCharacters(int characters)`
  - `StringOrMemory ReadMemory(int characters)`
  - `bool TryGetContentLength(out int length)`
  - `Encoding CurrentEncoding { get; set; }`
  - `int Index { get; set; }`
  - `char Item { get; }`
  - `int Length { get; }`
  - `string Text { get; }`

`class CharExtensions`
  - `int FromHex(char c)`
  - `bool IsAlphanumericAscii(char c)`
  - `bool IsCustomElementName(char c)`
  - `bool IsDigit(char c)`
  - `bool IsHex(char c)`
  - `bool IsInRange(char c, int lower, int upper)`
  - `bool IsInvalid(int c)`
  - `bool IsLetter(char c)`
  - `bool IsLineBreak(char c)`
  - `bool IsLowercaseAscii(char c)`
  - `bool IsName(char c)`
  - `bool IsNameStart(char c)`
  - `bool IsNonAscii(char c)`
  - `bool IsNonPrintable(char c)`
  - `bool IsNormalPathCharacter(char c)`
  - `bool IsNormalQueryCharacter(char c)`
  - `bool IsSpaceCharacter(char c)`
  - `bool IsUppercaseAscii(char c)`
  - `bool IsUrlCodePoint(char c)`
  - `bool IsWhiteSpaceCharacter(char c)`
  - `string ToHex(byte num)`
  - `string ToHex(char character)`

`interface IReadOnlyTextSource`
  - `Task PrefetchAllAsync(CancellationToken cancellationToken)`
  - `Task PrefetchAsync(int length, CancellationToken cancellationToken)`
  - `char ReadCharacter()`
  - `string ReadCharacters(int characters)`
  - `StringOrMemory ReadMemory(int characters)`
  - `bool TryGetContentLength(out int length)`
  - `Encoding CurrentEncoding { get; set; }`
  - `int Index { get; set; }`
  - `char Item { get; }`
  - `int Length { get; }`
  - `string Text { get; }`

`interface ITextSource`
  - `void InsertText(string content)`

`class Punycode`
  - `string Encode(string text)`

`class ReadOnlyMemoryTextSource`
  - `ReadOnlyMemoryTextSource(ReadOnlyMemory<char> memory)`
  - `ReadOnlyMemoryTextSource(string str)`
  - `void Dispose()`
  - `Task PrefetchAllAsync(CancellationToken cancellationToken)`
  - `Task PrefetchAsync(int length, CancellationToken cancellationToken)`
  - `char ReadCharacter()`
  - `string ReadCharacters(int characters)`
  - `StringOrMemory ReadMemory(int characters)`
  - `bool TryGetContentLength(out int length)`
  - `Encoding CurrentEncoding { get; set; }`
  - `int Index { get; set; }`
  - `char Item { get; }`
  - `int Length { get; }`
  - `string Text { get; }`

`class StringBuilderPool`
  - `StringBuilder Obtain()`
  - `string ToPool(StringBuilder sb)`
  - `bool IsPoolingDisabled { get; set; }`
  - `int MaxCount { get; set; }`
  - `int SizeLimit { get; set; }`

`class StringExtensions`
  - `string Collapse(string str)`
  - `string CollapseAndStrip(string str)`
  - `bool Contains(string[] list, string element, StringComparison comparison = ...)`
  - `string CssFunction(string value, string argument)`
  - `string CssString(string value)`
  - `int FromDec(string s)`
  - `int FromHex(string s)`
  - `bool Has(string value, char chr, int index = ...)`
  - `bool HasHyphen(string str, string value, StringComparison comparison = ...)`
  - `string HtmlEncode(string value, Encoding encoding)`
  - `StringOrMemory HtmlLower(StringOrMemory value)`
  - `string HtmlLower(string value)`
  - `bool Is(string current, string other)`
  - `bool Is(string current, StringOrMemory other)`
  - `bool Is(Span<char> current, string other)`
  - `bool Is(ReadOnlySpan<char> current, ReadOnlyMemory<char> other)`
  - `bool Is(ReadOnlySpan<char> current, ReadOnlySpan<char> other)`
  - `bool IsCustomElement(string tag)`
  - `bool IsCustomElement(StringOrMemory tag)`
  - `bool IsOneOf(string element, string item1, string item2)`
  - `bool IsOneOf(string element, string item1, string item2, string item3)`
  - `bool IsOneOf(string element, string item1, string item2, string item3, string item4)`
  - `bool IsOneOf(string element, string item1, string item2, string item3, string item4, string item5)`
  - `bool Isi(string current, string other)`
  - `bool Isi(string current, StringOrMemory other)`
  - `bool Isi(Span<char> current, string other)`
  - `bool Isi(Span<char> current, ReadOnlySpan<char> other)`
  - `bool Isi(Span<char> current, ReadOnlyMemory<char> other)`
  - `bool Isi(ReadOnlySpan<char> current, string other)`
  - `string NormalizeLineEndings(string value)`
  - `Sandboxes ParseSecuritySettings(string value, bool allowFullscreen = ...)`
  - `string ReplaceFirst(string text, string search, string replace)`
  - `string[] SplitCommas(string str)`
  - `string[] SplitSpaces(string str)`
  - `string[] SplitWithTrimming(string str, char ch)`
  - `string[] SplitWithoutTrimming(string str, char c)`
  - `string StripLeadingTrailingSpaces(string str)`
  - `string StripLineBreaks(string str)`
  - `bool ToBoolean(string value, bool defaultValue = ...)`
  - `double ToDouble(string value, double defaultValue = ...)`
  - `string ToEncodingType(string encType)`
  - `T ToEnum<T>(string value, T defaultValue)`
  - `string ToFormMethod(string method)`
  - `int ToInteger(string value, int defaultValue = ...)`
  - `UInt32 ToInteger(string value, UInt32 defaultValue = ...)`
  - `byte[] UrlDecode(string value)`
  - `string UrlEncode(byte[] content)`

`class StringSource`
  - `StringSource(string content)`
  - `char Back()`
  - `char Next()`
  - `string Content { get; }`
  - `char Current { get; }`
  - `int Index { get; }`
  - `bool IsDone { get; }`

`class StringSourceExtensions`
  - `char Back(StringSource source, int n)`
  - `char Next(StringSource source, int n)`
  - `char Peek(StringSource source)`
  - `char SkipSpaces(StringSource source)`

`class StringTextSource`
  - `StringTextSource(string source)`
  - `void Dispose()`
  - `Task PrefetchAllAsync(CancellationToken cancellationToken)`
  - `Task PrefetchAsync(int length, CancellationToken cancellationToken)`
  - `char ReadCharacter()`
  - `string ReadCharacters(int characters)`
  - `StringOrMemory ReadMemory(int characters)`
  - `bool TryGetContentLength(out int length)`
  - `Encoding CurrentEncoding { get; set; }`
  - `int Index { get; set; }`
  - `char Item { get; }`
  - `int Length { get; }`
  - `string Text { get; }`

`class TextEncoding`
  - `bool IsSupported(string charset)`
  - `bool IsUnicode(Encoding encoding)`
  - `Encoding Parse(string content)`
  - `Encoding Resolve(string charset)`

`struct TextPosition`
  - `TextPosition(UInt16 line, UInt16 column, int position)`
  - `TextPosition After(char chr)`
  - `TextPosition After(string str)`
  - `int CompareTo(TextPosition other)`
  - `bool Equals(object obj)`
  - `bool Equals(TextPosition other)`
  - `int GetHashCode()`
  - `TextPosition Shift(int columns)`
  - `string ToString()`
  - `int Column { get; }`
  - `int Index { get; }`
  - `int Line { get; }`
  - `int Position { get; }`

`struct TextRange`
  - `TextRange(TextPosition start, TextPosition end)`
  - `int CompareTo(TextRange other)`
  - `bool Equals(object obj)`
  - `bool Equals(TextRange other)`
  - `int GetHashCode()`
  - `string ToString()`
  - `TextPosition End { get; }`
  - `TextPosition Start { get; }`

`class TextSource`
  - `TextSource(string source)`
  - `TextSource(Stream baseStream, Encoding encoding = ...)`
  - `TextSource(ReadOnlyMemoryTextSource source)`
  - `TextSource(CharArrayTextSource source)`
  - `TextSource(StringTextSource source)`
  - `void Dispose()`
  - `IReadOnlyTextSource GetUnderlyingTextSource()`
  - `void InsertText(string content)`
  - `Task PrefetchAllAsync(CancellationToken cancellationToken)`
  - `Task PrefetchAsync(int length, CancellationToken cancellationToken)`
  - `char ReadCharacter()`
  - `string ReadCharacters(int characters)`
  - `StringOrMemory ReadMemory(int characters)`
  - `bool TryGetContentLength(out int length)`
  - `Encoding CurrentEncoding { get; set; }`
  - `int Index { get; set; }`
  - `char Item { get; }`
  - `int Length { get; }`
  - `string Text { get; }`

`class TextView`
  - `TextView(TextSource source, TextRange range)`
  - `TextRange Range { get; }`
  - `string Text { get; }`

`class XmlExtensions`
  - `bool IsPubidChar(char c)`
  - `bool IsQualifiedName(string str)`
  - `bool IsQualifiedName(StringOrMemory str)`
  - `bool IsValidAsCharRef(int chr)`
  - `bool IsXmlChar(char chr)`
  - `bool IsXmlName(char c)`
  - `bool IsXmlName(string str)`
  - `bool IsXmlName(StringOrMemory str)`
  - `bool IsXmlNameStart(char c)`

`class XhtmlMarkupFormatter`
  - `XhtmlMarkupFormatter()`
  - `XhtmlMarkupFormatter(bool emptyTagsToSelfClosing)`
  - `string CloseTag(IElement element, bool selfClosing)`
  - `string Comment(IComment comment)`
  - `string Doctype(IDocumentType doctype)`
  - `string EscapeText(string content)`
  - `string LiteralText(ICharacterData text)`
  - `string OpenTag(IElement element, bool selfClosing)`
  - `string Processing(IProcessingInstruction processing)`
  - `string Text(ICharacterData text)`
  - `string XmlNamespaceLocalName(string localName)`
  - `bool IsSelfClosingEmptyTags { get; }`

### Microsoft.ML.OnnxRuntime

`struct BFloat16`
  - `BFloat16(UInt16 v)`
  - `int CompareTo(object obj)`
  - `int CompareTo(BFloat16 other)`
  - `bool Equals(BFloat16 other)`
  - `bool Equals(object obj)`
  - `int GetHashCode()`
  - `bool IsFinite(BFloat16 value)`
  - `bool IsInfinity(BFloat16 value)`
  - `bool IsNaN(BFloat16 value)`
  - `bool IsNaNOrZero(BFloat16 value)`
  - `bool IsNegative(BFloat16 value)`
  - `bool IsNegativeInfinity(BFloat16 value)`
  - `bool IsNormal(BFloat16 value)`
  - `bool IsPositiveInfinity(BFloat16 value)`
  - `bool IsSubnormal(BFloat16 value)`
  - `BFloat16 Negate(BFloat16 value)`
  - `float ToFloat()`
  - `string ToString()`
  - `BFloat16 Epsilon { get; }`
  - `BFloat16 MaxValue { get; }`
  - `BFloat16 MinValue { get; }`
  - `BFloat16 NaN { get; }`
  - `BFloat16 NegativeInfinity { get; }`
  - `BFloat16 NegativeZero { get; }`
  - `BFloat16 One { get; }`
  - `BFloat16 Pi { get; }`
  - `BFloat16 PositiveInfinity { get; }`
  - `BFloat16 Zero { get; }`

`class CheckpointState`
  - `void AddProperty(string propertyName, long propertyValue)`
  - `void AddProperty(string propertyName, float propertyValue)`
  - `void AddProperty(string propertyName, string propertyValue)`
  - `OrtValue GetParameter(string parameterName)`
  - `object GetProperty(string propertyName)`
  - `CheckpointState LoadCheckpoint(string checkpointPath)`
  - `void SaveCheckpoint(CheckpointState state, string checkpointPath, bool includeOptimizerState = ...)`
  - `void UpdateParameter(string parameterName, OrtValue parameter)`
  - `bool IsInvalid { get; }`

`enum CoreMLFlags`
  - `values: COREML_FLAG_USE_NONE, COREML_FLAG_USE_CPU_ONLY, COREML_FLAG_ENABLE_ON_SUBGRAPH, COREML_FLAG_ONLY_ENABLE_DEVICE_WITH_ANE, COREML_FLAG_ONLY_ALLOW_STATIC_INPUT_SHAPES, COREML_FLAG_CREATE_MLPROGRAM, COREML_FLAG_USE_CPU_AND_GPU, COREML_FLAG_LAST`

`class DOrtLoggingFunction`
  - `DOrtLoggingFunction(object object, IntPtr method)`
  - `IAsyncResult BeginInvoke(IntPtr param, OrtLoggingLevel severity, string category, string logId, string codeLocation, string message, AsyncCallback callback, object object)`
  - `void EndInvoke(IAsyncResult result)`
  - `void Invoke(IntPtr param, OrtLoggingLevel severity, string category, string logId, string codeLocation, string message)`

`class DisposableNamedOnnxValue`
  - `void Dispose()`
  - `TensorElementType ElementType { get; }`

`enum ExecutionMode`
  - `values: ORT_SEQUENTIAL, ORT_PARALLEL`

`class FixedBufferOnnxValue`
  - `FixedBufferOnnxValue CreateFromMemory<T>(OrtMemoryInfo memoryInfo, Memory<T> memory, TensorElementType elementType, long[] shape, long bytesSize)`
  - `FixedBufferOnnxValue CreateFromTensor<T>(Tensor<T> value)`
  - `void Dispose()`

`struct Float16`
  - `Float16(UInt16 v)`
  - `int CompareTo(object obj)`
  - `int CompareTo(Float16 other)`
  - `bool Equals(Float16 other)`
  - `bool Equals(object obj)`
  - `int GetHashCode()`
  - `bool IsFinite(Float16 value)`
  - `bool IsInfinity(Float16 value)`
  - `bool IsNaN(Float16 value)`
  - `bool IsNaNOrZero(Float16 value)`
  - `bool IsNegative(Float16 value)`
  - `bool IsNegativeInfinity(Float16 value)`
  - `bool IsNormal(Float16 value)`
  - `bool IsPositiveInfinity(Float16 value)`
  - `bool IsSubnormal(Float16 value)`
  - `Float16 Negate(Float16 value)`
  - `float ToFloat()`
  - `string ToString()`
  - `Float16 Epsilon { get; }`
  - `Float16 MaxValue { get; }`
  - `Float16 MinValue { get; }`
  - `Float16 NaN { get; }`
  - `Float16 NegativeInfinity { get; }`
  - `Float16 NegativeZero { get; }`
  - `Float16 One { get; }`
  - `Float16 Pi { get; }`
  - `Float16 PositiveInfinity { get; }`
  - `Float16 Zero { get; }`

`enum GraphOptimizationLevel`
  - `values: ORT_DISABLE_ALL, ORT_ENABLE_BASIC, ORT_ENABLE_EXTENDED, ORT_ENABLE_ALL`

`class InferenceSession`
  - `InferenceSession(string modelPath)`
  - `InferenceSession(string modelPath, PrePackedWeightsContainer prepackedWeightsContainer)`
  - `InferenceSession(string modelPath, SessionOptions options)`
  - `InferenceSession(string modelPath, SessionOptions options, PrePackedWeightsContainer prepackedWeightsContainer)`
  - `InferenceSession(byte[] model)`
  - `InferenceSession(byte[] model, PrePackedWeightsContainer prepackedWeightsContainer)`
  - `InferenceSession(byte[] model, SessionOptions options)`
  - `InferenceSession(byte[] model, SessionOptions options, PrePackedWeightsContainer prepackedWeightsContainer)`
  - `OrtIoBinding CreateIoBinding()`
  - `void Dispose()`
  - `string EndProfiling()`
  - `IDisposableReadOnlyCollection<DisposableNamedOnnxValue> Run(IReadOnlyCollection<NamedOnnxValue> inputs)`
  - `IDisposableReadOnlyCollection<DisposableNamedOnnxValue> Run(IReadOnlyCollection<NamedOnnxValue> inputs, IReadOnlyCollection<string> outputNames)`
  - `IDisposableReadOnlyCollection<DisposableNamedOnnxValue> Run(IReadOnlyCollection<NamedOnnxValue> inputs, IReadOnlyCollection<string> outputNames, RunOptions options)`
  - `IDisposableReadOnlyCollection<DisposableNamedOnnxValue> Run(IReadOnlyCollection<string> inputNames, IReadOnlyCollection<FixedBufferOnnxValue> inputValues)`
  - `IDisposableReadOnlyCollection<DisposableNamedOnnxValue> Run(IReadOnlyCollection<string> inputNames, IReadOnlyCollection<FixedBufferOnnxValue> inputValues, IReadOnlyCollection<string> outputNames)`
  - `IDisposableReadOnlyCollection<DisposableNamedOnnxValue> Run(IReadOnlyCollection<string> inputNames, IReadOnlyCollection<FixedBufferOnnxValue> inputValues, IReadOnlyCollection<string> outputNames, RunOptions options)`
  - `void Run(IReadOnlyCollection<string> inputNames, IReadOnlyCollection<FixedBufferOnnxValue> inputValues, IReadOnlyCollection<string> outputNames, IReadOnlyCollection<FixedBufferOnnxValue> outputValues)`
  - `void Run(IReadOnlyCollection<string> inputNames, IReadOnlyCollection<FixedBufferOnnxValue> inputValues, IReadOnlyCollection<string> outputNames, IReadOnlyCollection<FixedBufferOnnxValue> outputValues, RunOptions options)`
  - `void Run(IReadOnlyCollection<NamedOnnxValue> inputs, IReadOnlyCollection<NamedOnnxValue> outputs)`
  - `void Run(IReadOnlyCollection<NamedOnnxValue> inputs, IReadOnlyCollection<NamedOnnxValue> outputs, RunOptions options)`
  - `void Run(IReadOnlyCollection<NamedOnnxValue> inputs, IReadOnlyCollection<string> outputNames, IReadOnlyCollection<FixedBufferOnnxValue> outputValues)`
  - `void Run(IReadOnlyCollection<NamedOnnxValue> inputs, IReadOnlyCollection<string> outputNames, IReadOnlyCollection<FixedBufferOnnxValue> outputValues, RunOptions options)`
  - `void Run(IReadOnlyCollection<string> inputNames, IReadOnlyCollection<FixedBufferOnnxValue> inputValues, IReadOnlyCollection<NamedOnnxValue> outputs)`
  - `void Run(IReadOnlyCollection<string> inputNames, IReadOnlyCollection<FixedBufferOnnxValue> inputValues, IReadOnlyCollection<NamedOnnxValue> outputs, RunOptions options)`
  - `IDisposableReadOnlyCollection<OrtValue> Run(RunOptions runOptions, IReadOnlyCollection<string> inputNames, IReadOnlyCollection<OrtValue> inputValues, IReadOnlyCollection<string> outputNames)`
  - `IDisposableReadOnlyCollection<OrtValue> Run(RunOptions runOptions, IReadOnlyDictionary<string, OrtValue> inputs, IReadOnlyCollection<string> outputNames)`
  - `void Run(RunOptions runOptions, IReadOnlyCollection<string> inputNames, IReadOnlyCollection<OrtValue> inputValues, IReadOnlyCollection<string> outputNames, IReadOnlyCollection<OrtValue> outputValues)`
  - `Task<IReadOnlyCollection<OrtValue>> RunAsync(RunOptions options, IReadOnlyCollection<string> inputNames, IReadOnlyCollection<OrtValue> inputValues, IReadOnlyCollection<string> outputNames, IReadOnlyCollection<OrtValue> outputValues)`
  - `void RunWithBinding(RunOptions runOptions, OrtIoBinding ioBinding)`
  - `IDisposableReadOnlyCollection<DisposableNamedOnnxValue> RunWithBindingAndNames(RunOptions runOptions, OrtIoBinding ioBinding, string[] names = ...)`
  - `IDisposableReadOnlyCollection<OrtValue> RunWithBoundResults(RunOptions runOptions, OrtIoBinding ioBinding)`
  - `IReadOnlyDictionary<string, NodeMetadata> InputMetadata { get; }`
  - `IReadOnlyList<string> InputNames { get; }`
  - `ModelMetadata ModelMetadata { get; }`
  - `IReadOnlyDictionary<string, NodeMetadata> OutputMetadata { get; }`
  - `IReadOnlyList<string> OutputNames { get; }`
  - `IReadOnlyDictionary<string, NodeMetadata> OverridableInitializerMetadata { get; }`
  - `UInt64 ProfilingStartTimeNs { get; }`

`class MapMetadata`
  - `TensorElementType KeyDataType { get; }`
  - `NodeMetadata ValueMetadata { get; }`

`struct MarshaledString`
  - `void Dispose()`

`struct MarshaledStringArray`
  - `void Dispose()`

`class ModelMetadata`
  - `Dictionary<string, string> CustomMetadataMap { get; }`
  - `string Description { get; }`
  - `string Domain { get; }`
  - `string GraphDescription { get; }`
  - `string GraphName { get; }`
  - `string ProducerName { get; }`
  - `long Version { get; }`

`class NamedOnnxValue`
  - `IDictionary<K, V> AsDictionary<K, V>()`
  - `IEnumerable<T> AsEnumerable<T>()`
  - `Tensor<T> AsTensor<T>()`
  - `NamedOnnxValue CreateFromMap<K, V>(string name, IDictionary<K, V> value)`
  - `NamedOnnxValue CreateFromSequence<T>(string name, IEnumerable<T> value)`
  - `NamedOnnxValue CreateFromTensor<T>(string name, Tensor<T> value)`
  - `string Name { get; set; }`
  - `object Value { get; set; }`
  - `OnnxValueType ValueType { get; set; }`

`enum NnapiFlags`
  - `values: NNAPI_FLAG_USE_NONE, NNAPI_FLAG_USE_FP16, NNAPI_FLAG_USE_NCHW, NNAPI_FLAG_CPU_DISABLED, NNAPI_FLAG_CPU_ONLY, NNAPI_FLAG_LAST`

`class NodeMetadata`
  - `MapMetadata AsMapMetadata()`
  - `OptionalMetadata AsOptionalMetadata()`
  - `SequenceMetadata AsSequenceMetadata()`
  - `int[] Dimensions { get; }`
  - `TensorElementType ElementDataType { get; }`
  - `Type ElementType { get; }`
  - `bool IsString { get; }`
  - `bool IsTensor { get; }`
  - `OnnxValueType OnnxValueType { get; }`
  - `string[] SymbolicDimensions { get; }`

`enum OnnxValueType`
  - `values: ONNX_TYPE_UNKNOWN, ONNX_TYPE_TENSOR, ONNX_TYPE_SEQUENCE, ONNX_TYPE_MAP, ONNX_TYPE_OPAQUE, ONNX_TYPE_SPARSETENSOR, ONNX_TYPE_OPTIONAL`

`class OptionalMetadata`
  - `NodeMetadata ElementMeta { get; }`

`class OrtAllocator`
  - `OrtAllocator(InferenceSession session, OrtMemoryInfo memInfo)`
  - `OrtMemoryAllocation Allocate(UInt32 size)`
  - `OrtAllocator DefaultInstance { get; }`
  - `OrtMemoryInfo Info { get; }`
  - `bool IsInvalid { get; }`

`enum OrtAllocatorType`
  - `values: DeviceAllocator, ArenaAllocator`

`class OrtArenaCfg`
  - `OrtArenaCfg(UInt32 maxMemory, int arenaExtendStrategy, int initialChunkSizeBytes, int maxDeadBytesPerChunk)`
  - `bool IsInvalid { get; }`

`class OrtCUDAProviderOptions`
  - `OrtCUDAProviderOptions()`
  - `string GetOptions()`
  - `void UpdateOptions(Dictionary<string, string> providerOptions)`
  - `bool IsInvalid { get; }`

`class OrtEnv`
  - `void CreateAndRegisterAllocator(OrtMemoryInfo memInfo, OrtArenaCfg arenaCfg)`
  - `OrtEnv CreateInstanceWithOptions(EnvironmentCreationOptions options)`
  - `void DisableTelemetryEvents()`
  - `void EnableTelemetryEvents()`
  - `string[] GetAvailableProviders()`
  - `string GetVersionString()`
  - `OrtEnv Instance()`
  - `OrtLoggingLevel EnvLogLevel { get; set; }`
  - `bool IsCreated { get; }`
  - `bool IsInvalid { get; }`

`class OrtExternalAllocation`
  - `OrtExternalAllocation(OrtMemoryInfo memInfo, long[] shape, TensorElementType elementType, IntPtr pointer, long sizeInBytes)`
  - `TensorElementType ElementType { get; set; }`
  - `OrtMemoryInfo Info { get; set; }`
  - `IntPtr Pointer { get; set; }`
  - `long[] Shape { get; set; }`
  - `long Size { get; set; }`

`class OrtIoBinding`
  - `void BindInput(string name, OrtValue ortValue)`
  - `void BindInput(string name, TensorElementType elementType, long[] shape, OrtMemoryAllocation allocation)`
  - `void BindInput(string name, OrtExternalAllocation allocation)`
  - `void BindInput(string name, FixedBufferOnnxValue fixedValue)`
  - `void BindOutput(string name, OrtValue ortValue)`
  - `void BindOutput(string name, TensorElementType elementType, long[] shape, OrtMemoryAllocation allocation)`
  - `void BindOutput(string name, OrtExternalAllocation allocation)`
  - `void BindOutput(string name, FixedBufferOnnxValue fixedValue)`
  - `void BindOutputToDevice(string name, OrtMemoryInfo memInfo)`
  - `void ClearBoundInputs()`
  - `void ClearBoundOutputs()`
  - `string[] GetOutputNames()`
  - `IDisposableReadOnlyCollection<OrtValue> GetOutputValues()`
  - `void SynchronizeBoundInputs()`
  - `void SynchronizeBoundOutputs()`
  - `bool IsInvalid { get; }`

`enum OrtLoggingLevel`
  - `values: ORT_LOGGING_LEVEL_VERBOSE, ORT_LOGGING_LEVEL_INFO, ORT_LOGGING_LEVEL_WARNING, ORT_LOGGING_LEVEL_ERROR, ORT_LOGGING_LEVEL_FATAL`

`class OrtLoraAdapter`
  - `OrtLoraAdapter Create(string adapterPath, OrtAllocator ortAllocator)`
  - `OrtLoraAdapter Create(byte[] bytes, OrtAllocator ortAllocator)`
  - `bool IsInvalid { get; }`

`struct OrtMapTypeInfo`
  - `TensorElementType KeyType { get; set; }`
  - `OrtTypeInfo ValueType { get; set; }`

`enum OrtMemType`
  - `values: CpuInput, CpuOutput, Cpu, Default`

`class OrtMemoryAllocation`
  - `OrtMemoryInfo Info { get; }`
  - `bool IsInvalid { get; }`
  - `UInt32 Size { get; set; }`

`class OrtMemoryInfo`
  - `OrtMemoryInfo(byte[] utf8AllocatorName, OrtAllocatorType allocatorType, int deviceId, OrtMemType memoryType)`
  - `OrtMemoryInfo(string allocatorName, OrtAllocatorType allocatorType, int deviceId, OrtMemType memoryType)`
  - `bool Equals(object obj)`
  - `bool Equals(OrtMemoryInfo other)`
  - `OrtAllocatorType GetAllocatorType()`
  - `int GetHashCode()`
  - `OrtMemType GetMemoryType()`
  - `OrtMemoryInfo DefaultInstance { get; }`
  - `int Id { get; }`
  - `bool IsInvalid { get; }`
  - `string Name { get; }`

`class OrtROCMProviderOptions`
  - `OrtROCMProviderOptions()`
  - `string GetOptions()`
  - `void UpdateOptions(Dictionary<string, string> providerOptions)`
  - `bool IsInvalid { get; }`

`struct OrtSequenceOrOptionalTypeInfo`
  - `OrtTypeInfo ElementType { get; set; }`

`class OrtTensorRTProviderOptions`
  - `OrtTensorRTProviderOptions()`
  - `int GetDeviceId()`
  - `string GetOptions()`
  - `void UpdateOptions(Dictionary<string, string> providerOptions)`
  - `bool IsInvalid { get; }`

`struct OrtTensorTypeAndShapeInfo`
  - `int DimensionsCount { get; }`
  - `long ElementCount { get; set; }`
  - `TensorElementType ElementDataType { get; set; }`
  - `bool IsString { get; }`
  - `long[] Shape { get; set; }`

`class OrtThreadingOptions`
  - `OrtThreadingOptions()`
  - `void SetGlobalDenormalAsZero()`
  - `int GlobalInterOpNumThreads { set; }`
  - `int GlobalIntraOpNumThreads { set; }`
  - `bool GlobalSpinControl { set; }`
  - `bool IsInvalid { get; }`

`class OrtTypeInfo`
  - `OrtMapTypeInfo MapTypeInfo { get; }`
  - `OnnxValueType OnnxType { get; set; }`
  - `OrtSequenceOrOptionalTypeInfo OptionalTypeInfo { get; }`
  - `OrtSequenceOrOptionalTypeInfo SequenceTypeInfo { get; }`
  - `OrtTensorTypeAndShapeInfo TensorTypeAndShapeInfo { get; }`

`class OrtValue`
  - `OrtValue CreateAllocatedTensorValue(OrtAllocator allocator, TensorElementType elementType, long[] shape)`
  - `OrtValue CreateFromStringTensor(Tensor<string> tensor)`
  - `OrtValue CreateMap(OrtValue keys, OrtValue values)`
  - `OrtValue CreateMap<K, V>(K[] keys, V[] values)`
  - `OrtValue CreateMapWithStringKeys<V>(IReadOnlyCollection<string> keys, V[] values)`
  - `OrtValue CreateMapWithStringValues<K>(K[] keys, IReadOnlyCollection<string> values)`
  - `OrtValue CreateSequence(ICollection<OrtValue> ortValues)`
  - `OrtValue CreateTensorValueFromMemory<T>(OrtMemoryInfo memoryInfo, Memory<T> memory, long[] shape)`
  - `OrtValue CreateTensorValueFromMemory<T>(T[] data, long[] shape)`
  - `OrtValue CreateTensorValueWithData(OrtMemoryInfo memInfo, TensorElementType elementType, long[] shape, IntPtr dataBufferPtr, long bufferLengthInBytes)`
  - `OrtValue CreateTensorWithEmptyStrings(OrtAllocator allocator, long[] shape)`
  - `void Dispose()`
  - `string GetStringElement(int index)`
  - `ReadOnlyMemory<char> GetStringElementAsMemory(int index)`
  - `ReadOnlySpan<byte> GetStringElementAsSpan(int index)`
  - `string[] GetStringTensorAsArray()`
  - `ReadOnlySpan<T> GetTensorDataAsSpan<T>()`
  - `OrtMemoryInfo GetTensorMemoryInfo()`
  - `Span<T> GetTensorMutableDataAsSpan<T>()`
  - `Span<byte> GetTensorMutableRawData()`
  - `OrtTensorTypeAndShapeInfo GetTensorTypeAndShape()`
  - `OrtTypeInfo GetTypeInfo()`
  - `OrtValue GetValue(int index, OrtAllocator allocator)`
  - `int GetValueCount()`
  - `void ProcessMap(MapVisitor visitor, OrtAllocator allocator)`
  - `void ProcessSequence(SequenceElementVisitor visitor, OrtAllocator allocator)`
  - `void StringTensorSetElementAt(ReadOnlySpan<char> str, int index)`
  - `void StringTensorSetElementAt(ReadOnlyMemory<char> rom, int index)`
  - `void StringTensorSetElementAt(ReadOnlySpan<byte> utf8Bytes, int index)`
  - `bool IsSparseTensor { get; }`
  - `bool IsTensor { get; }`
  - `OnnxValueType OnnxType { get; set; }`
  - `OrtValue Value { get; }`

`class PrePackedWeightsContainer`
  - `PrePackedWeightsContainer()`
  - `bool IsInvalid { get; }`

`class ProviderOptionsValueHelper`
  - `ProviderOptionsValueHelper()`
  - `void StringToDict(string s, Dictionary<string, string> dict)`

`class RunOptions`
  - `RunOptions()`
  - `void AddActiveLoraAdapter(OrtLoraAdapter loraAdapter)`
  - `void AddRunConfigEntry(string configKey, string configValue)`
  - `bool IsInvalid { get; }`
  - `string LogId { get; set; }`
  - `OrtLoggingLevel LogSeverityLevel { get; set; }`
  - `int LogVerbosityLevel { get; set; }`
  - `bool Terminate { get; set; }`

`class SequenceMetadata`
  - `NodeMetadata ElementMeta { get; }`

`class SessionOptions`
  - `SessionOptions()`
  - `void AddFreeDimensionOverride(string dimDenotation, long dimValue)`
  - `void AddFreeDimensionOverrideByName(string dimName, long dimValue)`
  - `void AddInitializer(string name, OrtValue ortValue)`
  - `void AddSessionConfigEntry(string configKey, string configValue)`
  - `void AppendExecutionProvider(string providerName, Dictionary<string, string> providerOptions = ...)`
  - `void AppendExecutionProvider_CPU(int useArena = ...)`
  - `void AppendExecutionProvider_CUDA(int deviceId = ...)`
  - `void AppendExecutionProvider_CUDA(OrtCUDAProviderOptions cudaProviderOptions)`
  - `void AppendExecutionProvider_CoreML(CoreMLFlags coremlFlags = ...)`
  - `void AppendExecutionProvider_DML(int deviceId = ...)`
  - `void AppendExecutionProvider_Dnnl(int useArena = ...)`
  - `void AppendExecutionProvider_MIGraphX(int deviceId = ...)`
  - `void AppendExecutionProvider_Nnapi(NnapiFlags nnapiFlags = ...)`
  - `void AppendExecutionProvider_OpenVINO(string deviceId = ...)`
  - `void AppendExecutionProvider_ROCm(int deviceId = ...)`
  - `void AppendExecutionProvider_ROCm(OrtROCMProviderOptions rocmProviderOptions)`
  - `void AppendExecutionProvider_Tensorrt(int deviceId = ...)`
  - `void AppendExecutionProvider_Tensorrt(OrtTensorRTProviderOptions trtProviderOptions)`
  - `void AppendExecutionProvider_Tvm(string settings = ...)`
  - `void DisablePerSessionThreads()`
  - `SessionOptions MakeSessionOptionWithCudaProvider(int deviceId = ...)`
  - `SessionOptions MakeSessionOptionWithCudaProvider(OrtCUDAProviderOptions cudaProviderOptions)`
  - `SessionOptions MakeSessionOptionWithRocmProvider(int deviceId = ...)`
  - `SessionOptions MakeSessionOptionWithRocmProvider(OrtROCMProviderOptions rocmProviderOptions)`
  - `SessionOptions MakeSessionOptionWithTensorrtProvider(int deviceId = ...)`
  - `SessionOptions MakeSessionOptionWithTensorrtProvider(OrtTensorRTProviderOptions trtProviderOptions)`
  - `SessionOptions MakeSessionOptionWithTvmProvider(string settings = ...)`
  - `void RegisterCustomOpLibrary(string libraryPath)`
  - `void RegisterCustomOpLibraryV2(string libraryPath, out IntPtr libraryHandle)`
  - `void RegisterOrtExtensions()`
  - `bool EnableCpuMemArena { get; set; }`
  - `bool EnableMemoryPattern { get; set; }`
  - `bool EnableProfiling { get; set; }`
  - `ExecutionMode ExecutionMode { get; set; }`
  - `GraphOptimizationLevel GraphOptimizationLevel { get; set; }`
  - `int InterOpNumThreads { get; set; }`
  - `int IntraOpNumThreads { get; set; }`
  - `bool IsInvalid { get; }`
  - `string LogId { get; set; }`
  - `OrtLoggingLevel LogSeverityLevel { get; set; }`
  - `int LogVerbosityLevel { get; set; }`
  - `string OptimizedModelFilePath { get; set; }`
  - `string ProfileOutputPathPrefix { get; set; }`

`class SessionOptionsContainer`
  - `SessionOptions ApplyConfiguration(SessionOptions options, string configuration = ..., bool useDefaultAsFallback = ...)`
  - `SessionOptions Create(string configuration = ..., bool useDefaultAsFallback = ...)`
  - `void Register(Action<SessionOptions> defaultHandler)`
  - `void Register(string configuration, Action<SessionOptions> handler)`
  - `void Reset()`

`class TensorTypeAndShape`
  - `int[] Dimensions { get; }`
  - `TensorElementType ElementDataType { get; }`
  - `TensorElementTypeInfo ElementTypeInfo { get; }`
  - `string[] SymbolicDimensions { get; }`

`class ArrayTensorExtensions`
  - `DenseTensor<T> ToTensor<T>(T[] array)`
  - `DenseTensor<T> ToTensor<T>(T[] array, bool reverseStride = ...)`
  - `DenseTensor<T> ToTensor<T>(T[] array, bool reverseStride = ...)`
  - `DenseTensor<T> ToTensor<T>(T[] array, bool reverseStride = ...)`
  - `DenseTensor<T> ToTensor<T>(Array array, bool reverseStride = ...)`

`class DenseTensor<T>`
  - `DenseTensor`1(int length)`
  - `DenseTensor`1(ReadOnlySpan<int> dimensions, bool reverseStride = ...)`
  - `DenseTensor`1(Memory<T> memory, ReadOnlySpan<int> dimensions, bool reverseStride = ...)`
  - `Tensor<T> Clone()`
  - `Tensor<TResult> CloneEmpty<TResult>(ReadOnlySpan<int> dimensions)`
  - `T GetValue(int index)`
  - `Tensor<T> Reshape(ReadOnlySpan<int> dimensions)`
  - `void SetValue(int index, T value)`
  - `Memory<T> Buffer { get; }`

`class ShapeUtils`
  - `long GetIndex(ReadOnlySpan<long> strides, ReadOnlySpan<long> indices, int startFromDimension = ...)`
  - `long GetSizeForShape(ReadOnlySpan<long> shape)`
  - `long[] GetStrides(ReadOnlySpan<long> dimensions)`

`class Tensor`
  - `Tensor<T> CreateFromDiagonal<T>(Tensor<T> diagonal)`
  - `Tensor<T> CreateFromDiagonal<T>(Tensor<T> diagonal, int offset)`
  - `Tensor<T> CreateIdentity<T>(int size)`
  - `Tensor<T> CreateIdentity<T>(int size, bool columMajor)`
  - `Tensor<T> CreateIdentity<T>(int size, bool columMajor, T oneValue)`

`class TensorBase`
  - `TensorElementTypeInfo GetElementTypeInfo(TensorElementType elementType)`
  - `TensorTypeInfo GetTypeInfo(Type type)`
  - `TensorTypeInfo GetTypeInfo()`

`enum TensorElementType`
  - `values: Float, UInt8, Int8, UInt16, Int16, Int32, Int64, String, Bool, Float16, Double, UInt32, UInt64, Complex64, Complex128, BFloat16, DataTypeMax`

`class TensorElementTypeInfo`
  - `TensorElementTypeInfo(Type type, int typeSize)`
  - `bool IsString { get; set; }`
  - `Type TensorType { get; set; }`
  - `int TypeSize { get; set; }`

`class TensorTypeInfo`
  - `TensorTypeInfo(TensorElementType elementType, int typeSize)`
  - `TensorElementType ElementType { get; set; }`
  - `bool IsString { get; }`
  - `int TypeSize { get; set; }`

`class Tensor<T>`
  - `Tensor<T> Clone()`
  - `Tensor<T> CloneEmpty()`
  - `Tensor<T> CloneEmpty(ReadOnlySpan<int> dimensions)`
  - `Tensor<TResult> CloneEmpty<TResult>()`
  - `Tensor<TResult> CloneEmpty<TResult>(ReadOnlySpan<int> dimensions)`
  - `int Compare(Tensor<T> left, Tensor<T> right)`
  - `bool Equals(Tensor<T> left, Tensor<T> right)`
  - `void Fill(T value)`
  - `string GetArrayString(bool includeWhitespace = ...)`
  - `Tensor<T> GetDiagonal()`
  - `Tensor<T> GetDiagonal(int offset)`
  - `Tensor<T> GetTriangle()`
  - `Tensor<T> GetTriangle(int offset)`
  - `Tensor<T> GetTriangle(int offset, bool upper)`
  - `Tensor<T> GetUpperTriangle()`
  - `Tensor<T> GetUpperTriangle(int offset)`
  - `T GetValue(int index)`
  - `Tensor<T> Reshape(ReadOnlySpan<int> dimensions)`
  - `void SetValue(int index, T value)`
  - `DenseTensor<T> ToDenseTensor()`
  - `ReadOnlySpan<int> Dimensions { get; }`
  - `bool IsFixedSize { get; }`
  - `bool IsReadOnly { get; }`
  - `bool IsReversedStride { get; }`
  - `T Item { get; set; }`
  - `T Item { get; set; }`
  - `long Length { get; }`
  - `int Rank { get; }`
  - `ReadOnlySpan<int> Strides { get; }`

`class TrainingSession`
  - `TrainingSession(CheckpointState state, string trainModelPath, string evalModelPath, string optimizerModelPath)`
  - `TrainingSession(CheckpointState state, string trainModelPath, string optimizerModelPath)`
  - `TrainingSession(SessionOptions options, CheckpointState state, string trainModelPath, string evalModelPath, string optimizerModelPath)`
  - `void Dispose()`
  - `void EvalStep(IReadOnlyCollection<FixedBufferOnnxValue> inputValues, IReadOnlyCollection<FixedBufferOnnxValue> outputValues)`
  - `void EvalStep(RunOptions options, IReadOnlyCollection<FixedBufferOnnxValue> inputValues, IReadOnlyCollection<FixedBufferOnnxValue> outputValues)`
  - `IDisposableReadOnlyCollection<OrtValue> EvalStep(IReadOnlyCollection<OrtValue> inputValues)`
  - `void ExportModelForInferencing(string inferenceModelPath, IReadOnlyCollection<string> graphOutputNames)`
  - `void FromBuffer(OrtValue ortValue, bool onlyTrainable)`
  - `float GetLearningRate()`
  - `List<string> InputNames(bool training)`
  - `void LazyResetGrad()`
  - `void OptimizerStep()`
  - `void OptimizerStep(RunOptions options)`
  - `List<string> OutputNames(bool training)`
  - `void RegisterLinearLRScheduler(long warmupStepCount, long totalStepCount, float initialLearningRate)`
  - `void SchedulerStep()`
  - `void SetLearningRate(float learningRate)`
  - `OrtValue ToBuffer(bool onlyTrainable)`
  - `void TrainStep(IReadOnlyCollection<FixedBufferOnnxValue> inputValues, IReadOnlyCollection<FixedBufferOnnxValue> outputValues)`
  - `void TrainStep(RunOptions options, IReadOnlyCollection<FixedBufferOnnxValue> inputValues, IReadOnlyCollection<FixedBufferOnnxValue> outputValues)`
  - `IDisposableReadOnlyCollection<DisposableNamedOnnxValue> TrainStep(IReadOnlyCollection<FixedBufferOnnxValue> inputValues)`
  - `IDisposableReadOnlyCollection<DisposableNamedOnnxValue> TrainStep(RunOptions options, IReadOnlyCollection<FixedBufferOnnxValue> inputValues)`
  - `IDisposableReadOnlyCollection<OrtValue> TrainStep(IReadOnlyCollection<OrtValue> inputValues)`

`class TrainingUtils`
  - `TrainingUtils()`
  - `void SetSeed(long seed)`

### ModelContextProtocol

`interface IMcpMessageFilterBuilder`
  - `IServiceCollection Services { get; }`

`interface IMcpRequestFilterBuilder`
  - `IServiceCollection Services { get; }`

`interface IMcpServerBuilder`
  - `IServiceCollection Services { get; }`

`class McpMessageFilterBuilderExtensions`
  - `IMcpMessageFilterBuilder AddIncomingFilter(IMcpMessageFilterBuilder builder, McpMessageFilter filter)`
  - `IMcpMessageFilterBuilder AddOutgoingFilter(IMcpMessageFilterBuilder builder, McpMessageFilter filter)`

`class McpRequestFilterBuilderExtensions`
  - `IMcpRequestFilterBuilder AddCallToolFilter(IMcpRequestFilterBuilder builder, McpRequestFilter<CallToolRequestParams, CallToolResult> filter)`
  - `IMcpRequestFilterBuilder AddCompleteFilter(IMcpRequestFilterBuilder builder, McpRequestFilter<CompleteRequestParams, CompleteResult> filter)`
  - `IMcpRequestFilterBuilder AddGetPromptFilter(IMcpRequestFilterBuilder builder, McpRequestFilter<GetPromptRequestParams, GetPromptResult> filter)`
  - `IMcpRequestFilterBuilder AddListPromptsFilter(IMcpRequestFilterBuilder builder, McpRequestFilter<ListPromptsRequestParams, ListPromptsResult> filter)`
  - `IMcpRequestFilterBuilder AddListResourceTemplatesFilter(IMcpRequestFilterBuilder builder, McpRequestFilter<ListResourceTemplatesRequestParams, ListResourceTemplatesResult> filter)`
  - `IMcpRequestFilterBuilder AddListResourcesFilter(IMcpRequestFilterBuilder builder, McpRequestFilter<ListResourcesRequestParams, ListResourcesResult> filter)`
  - `IMcpRequestFilterBuilder AddListToolsFilter(IMcpRequestFilterBuilder builder, McpRequestFilter<ListToolsRequestParams, ListToolsResult> filter)`
  - `IMcpRequestFilterBuilder AddReadResourceFilter(IMcpRequestFilterBuilder builder, McpRequestFilter<ReadResourceRequestParams, ReadResourceResult> filter)`
  - `IMcpRequestFilterBuilder AddSetLoggingLevelFilter(IMcpRequestFilterBuilder builder, McpRequestFilter<SetLevelRequestParams, EmptyResult> filter)`
  - `IMcpRequestFilterBuilder AddSubscribeToResourcesFilter(IMcpRequestFilterBuilder builder, McpRequestFilter<SubscribeRequestParams, EmptyResult> filter)`
  - `IMcpRequestFilterBuilder AddUnsubscribeFromResourcesFilter(IMcpRequestFilterBuilder builder, McpRequestFilter<UnsubscribeRequestParams, EmptyResult> filter)`

`class McpServerBuilderExtensions`
  - `IMcpServerBuilder WithCallToolHandler(IMcpServerBuilder builder, McpRequestHandler<CallToolRequestParams, CallToolResult> handler)`
  - `IMcpServerBuilder WithCompleteHandler(IMcpServerBuilder builder, McpRequestHandler<CompleteRequestParams, CompleteResult> handler)`
  - `IMcpServerBuilder WithGetPromptHandler(IMcpServerBuilder builder, McpRequestHandler<GetPromptRequestParams, GetPromptResult> handler)`
  - `IMcpServerBuilder WithListPromptsHandler(IMcpServerBuilder builder, McpRequestHandler<ListPromptsRequestParams, ListPromptsResult> handler)`
  - `IMcpServerBuilder WithListResourceTemplatesHandler(IMcpServerBuilder builder, McpRequestHandler<ListResourceTemplatesRequestParams, ListResourceTemplatesResult> handler)`
  - `IMcpServerBuilder WithListResourcesHandler(IMcpServerBuilder builder, McpRequestHandler<ListResourcesRequestParams, ListResourcesResult> handler)`
  - `IMcpServerBuilder WithListToolsHandler(IMcpServerBuilder builder, McpRequestHandler<ListToolsRequestParams, ListToolsResult> handler)`
  - `IMcpServerBuilder WithMessageFilters(IMcpServerBuilder builder, Action<IMcpMessageFilterBuilder> configure)`
  - `IMcpServerBuilder WithPrompts<TPromptType>(IMcpServerBuilder builder, JsonSerializerOptions serializerOptions = ...)`
  - `IMcpServerBuilder WithPrompts<TPromptType>(IMcpServerBuilder builder, TPromptType target, JsonSerializerOptions serializerOptions = ...)`
  - `IMcpServerBuilder WithPrompts(IMcpServerBuilder builder, IEnumerable<McpServerPrompt> prompts)`
  - `IMcpServerBuilder WithPrompts(IMcpServerBuilder builder, IEnumerable<Type> promptTypes, JsonSerializerOptions serializerOptions = ...)`
  - `IMcpServerBuilder WithPromptsFromAssembly(IMcpServerBuilder builder, Assembly promptAssembly = ..., JsonSerializerOptions serializerOptions = ...)`
  - `IMcpServerBuilder WithReadResourceHandler(IMcpServerBuilder builder, McpRequestHandler<ReadResourceRequestParams, ReadResourceResult> handler)`
  - `IMcpServerBuilder WithRequestFilters(IMcpServerBuilder builder, Action<IMcpRequestFilterBuilder> configure)`
  - `IMcpServerBuilder WithResources<TResourceType>(IMcpServerBuilder builder)`
  - `IMcpServerBuilder WithResources<TResourceType>(IMcpServerBuilder builder, TResourceType target)`
  - `IMcpServerBuilder WithResources(IMcpServerBuilder builder, IEnumerable<McpServerResource> resourceTemplates)`
  - `IMcpServerBuilder WithResources(IMcpServerBuilder builder, IEnumerable<Type> resourceTemplateTypes)`
  - `IMcpServerBuilder WithResourcesFromAssembly(IMcpServerBuilder builder, Assembly resourceAssembly = ...)`
  - `IMcpServerBuilder WithSetLoggingLevelHandler(IMcpServerBuilder builder, McpRequestHandler<SetLevelRequestParams, EmptyResult> handler)`
  - `IMcpServerBuilder WithStdioServerTransport(IMcpServerBuilder builder)`
  - `IMcpServerBuilder WithStreamServerTransport(IMcpServerBuilder builder, Stream inputStream, Stream outputStream)`
  - `IMcpServerBuilder WithSubscribeToResourcesHandler(IMcpServerBuilder builder, McpRequestHandler<SubscribeRequestParams, EmptyResult> handler)`
  - `IMcpServerBuilder WithTools<TToolType>(IMcpServerBuilder builder, JsonSerializerOptions serializerOptions = ...)`
  - `IMcpServerBuilder WithTools<TToolType>(IMcpServerBuilder builder, TToolType target, JsonSerializerOptions serializerOptions = ...)`
  - `IMcpServerBuilder WithTools(IMcpServerBuilder builder, IEnumerable<McpServerTool> tools)`
  - `IMcpServerBuilder WithTools(IMcpServerBuilder builder, IEnumerable<Type> toolTypes, JsonSerializerOptions serializerOptions = ...)`
  - `IMcpServerBuilder WithToolsFromAssembly(IMcpServerBuilder builder, Assembly toolAssembly = ..., JsonSerializerOptions serializerOptions = ...)`
  - `IMcpServerBuilder WithUnsubscribeFromResourcesHandler(IMcpServerBuilder builder, McpRequestHandler<UnsubscribeRequestParams, EmptyResult> handler)`

`class McpServerServiceCollectionExtensions`
  - `IMcpServerBuilder AddMcpServer(IServiceCollection services, Action<McpServerOptions> configureOptions = ...)`

`class DistributedCacheEventStreamStore`
  - `DistributedCacheEventStreamStore(IOptions<DistributedCacheEventStreamStoreOptions> options, ILogger<DistributedCacheEventStreamStore> logger = ...)`
  - `ValueTask<ISseEventStreamWriter> CreateStreamAsync(SseEventStreamOptions options, CancellationToken cancellationToken = ...)`
  - `ValueTask<ISseEventStreamReader> GetStreamReaderAsync(string lastEventId, CancellationToken cancellationToken = ...)`

`class DistributedCacheEventStreamStoreOptions`
  - `DistributedCacheEventStreamStoreOptions()`
  - `IDistributedCache Cache { get; set; }`
  - `Nullable<TimeSpan> EventAbsoluteExpiration { get; set; }`
  - `Nullable<TimeSpan> EventSlidingExpiration { get; set; }`
  - `Nullable<TimeSpan> MetadataAbsoluteExpiration { get; set; }`
  - `Nullable<TimeSpan> MetadataSlidingExpiration { get; set; }`
  - `TimeSpan StreamReaderPollingInterval { get; set; }`

### ModelContextProtocol.Core

`class AuthorizationRedirectDelegate`
  - `AuthorizationRedirectDelegate(object object, IntPtr method)`
  - `IAsyncResult BeginInvoke(Uri authorizationUri, Uri redirectUri, CancellationToken cancellationToken, AsyncCallback callback, object object)`
  - `Task<string> EndInvoke(IAsyncResult result)`
  - `Task<string> Invoke(Uri authorizationUri, Uri redirectUri, CancellationToken cancellationToken)`

`class ClientOAuthOptions`
  - `ClientOAuthOptions()`
  - `IDictionary<string, string> AdditionalAuthorizationParameters { get; set; }`
  - `Func<IReadOnlyList<Uri>, Uri> AuthServerSelector { get; set; }`
  - `AuthorizationRedirectDelegate AuthorizationRedirectDelegate { get; set; }`
  - `string ClientId { get; set; }`
  - `Uri ClientMetadataDocumentUri { get; set; }`
  - `string ClientSecret { get; set; }`
  - `DynamicClientRegistrationOptions DynamicClientRegistration { get; set; }`
  - `Uri RedirectUri { get; set; }`
  - `IEnumerable<string> Scopes { get; set; }`
  - `ITokenCache TokenCache { get; set; }`

`class DynamicClientRegistrationOptions`
  - `DynamicClientRegistrationOptions()`
  - `string ClientName { get; set; }`
  - `Uri ClientUri { get; set; }`
  - `string InitialAccessToken { get; set; }`
  - `Func<DynamicClientRegistrationResponse, CancellationToken, Task> ResponseDelegate { get; set; }`

`class DynamicClientRegistrationResponse`
  - `DynamicClientRegistrationResponse()`
  - `string ClientId { get; set; }`
  - `Nullable<long> ClientIdIssuedAt { get; set; }`
  - `string ClientSecret { get; set; }`
  - `Nullable<long> ClientSecretExpiresAt { get; set; }`
  - `IList<string> GrantTypes { get; set; }`
  - `IList<string> RedirectUris { get; set; }`
  - `IList<string> ResponseTypes { get; set; }`
  - `string TokenEndpointAuthMethod { get; set; }`

`interface ITokenCache`
  - `ValueTask<TokenContainer> GetTokensAsync(CancellationToken cancellationToken)`
  - `ValueTask StoreTokensAsync(TokenContainer tokens, CancellationToken cancellationToken)`

`class IdentityAssertionGrantContext`
  - `IdentityAssertionGrantContext()`
  - `Uri AuthorizationServerUrl { get; set; }`
  - `Uri ResourceUrl { get; set; }`

`class IdentityAssertionGrantException`
  - `IdentityAssertionGrantException(string message, string errorCode = ..., string errorDescription = ..., string errorUri = ...)`
  - `string ErrorCode { get; }`
  - `string ErrorDescription { get; }`
  - `string ErrorUri { get; }`

`class IdentityAssertionGrantIdTokenCallback`
  - `IdentityAssertionGrantIdTokenCallback(object object, IntPtr method)`
  - `IAsyncResult BeginInvoke(IdentityAssertionGrantContext context, CancellationToken cancellationToken, AsyncCallback callback, object object)`
  - `Task<string> EndInvoke(IAsyncResult result)`
  - `Task<string> Invoke(IdentityAssertionGrantContext context, CancellationToken cancellationToken)`

`class IdentityAssertionGrantProvider`
  - `IdentityAssertionGrantProvider(IdentityAssertionGrantProviderOptions options, HttpClient httpClient, ILoggerFactory loggerFactory = ...)`
  - `Task<TokenContainer> GetAccessTokenAsync(Uri resourceUrl, Uri authorizationServerUrl, CancellationToken cancellationToken = ...)`
  - `void InvalidateCache()`

`class IdentityAssertionGrantProviderOptions`
  - `IdentityAssertionGrantProviderOptions()`
  - `string ClientId { get; set; }`
  - `string ClientSecret { get; set; }`
  - `IdentityAssertionGrantIdTokenCallback IdTokenCallback { get; set; }`
  - `string IdpClientId { get; set; }`
  - `string IdpClientSecret { get; set; }`
  - `string IdpScope { get; set; }`
  - `string IdpTokenEndpoint { get; set; }`
  - `string IdpUrl { get; set; }`
  - `string Scope { get; set; }`

`class ProtectedResourceMetadata`
  - `ProtectedResourceMetadata()`
  - `ProtectedResourceMetadata Clone(string derivedResource = ...)`
  - `IList<string> AuthorizationDetailsTypesSupported { get; set; }`
  - `IList<string> AuthorizationServers { get; set; }`
  - `IList<string> BearerMethodsSupported { get; set; }`
  - `Nullable<bool> DpopBoundAccessTokensRequired { get; set; }`
  - `IList<string> DpopSigningAlgValuesSupported { get; set; }`
  - `string JwksUri { get; set; }`
  - `string Resource { get; set; }`
  - `string ResourceDocumentation { get; set; }`
  - `string ResourceName { get; set; }`
  - `string ResourcePolicyUri { get; set; }`
  - `IList<string> ResourceSigningAlgValuesSupported { get; set; }`
  - `string ResourceTosUri { get; set; }`
  - `IList<string> ScopesSupported { get; set; }`
  - `Nullable<bool> TlsClientCertificateBoundAccessTokens { get; set; }`

`class TokenContainer`
  - `TokenContainer()`
  - `string AccessToken { get; set; }`
  - `Nullable<int> ExpiresIn { get; set; }`
  - `DateTimeOffset ObtainedAt { get; set; }`
  - `string RefreshToken { get; set; }`
  - `string Scope { get; set; }`
  - `string TokenType { get; set; }`

`class ClientCompletionDetails`
  - `ClientCompletionDetails()`
  - `Exception Exception { get; set; }`

`class ClientTransportClosedException`
  - `ClientTransportClosedException(ClientCompletionDetails details)`
  - `ClientCompletionDetails Details { get; }`

`class HttpClientCompletionDetails`
  - `HttpClientCompletionDetails()`
  - `Nullable<HttpStatusCode> HttpStatusCode { get; set; }`

`class HttpClientTransport`
  - `HttpClientTransport(HttpClientTransportOptions transportOptions, ILoggerFactory loggerFactory = ...)`
  - `HttpClientTransport(HttpClientTransportOptions transportOptions, HttpClient httpClient, ILoggerFactory loggerFactory = ..., bool ownsHttpClient = ...)`
  - `Task<ITransport> ConnectAsync(CancellationToken cancellationToken = ...)`
  - `ValueTask DisposeAsync()`
  - `string Name { get; }`

`class HttpClientTransportOptions`
  - `HttpClientTransportOptions()`
  - `IDictionary<string, string> AdditionalHeaders { get; set; }`
  - `TimeSpan ConnectionTimeout { get; set; }`
  - `TimeSpan DefaultReconnectionInterval { get; set; }`
  - `Uri Endpoint { get; set; }`
  - `string KnownSessionId { get; set; }`
  - `int MaxReconnectionAttempts { get; set; }`
  - `string Name { get; set; }`
  - `ClientOAuthOptions OAuth { get; set; }`
  - `bool OwnsSession { get; set; }`
  - `HttpTransportMode TransportMode { get; set; }`

`enum HttpTransportMode`
  - `values: AutoDetect, StreamableHttp, Sse`

`interface IClientTransport`
  - `Task<ITransport> ConnectAsync(CancellationToken cancellationToken = ...)`
  - `string Name { get; }`

`class McpClient`
  - `ValueTask<McpTask> CallToolAsTaskAsync(string toolName, IReadOnlyDictionary<string, object> arguments = ..., McpTaskMetadata taskMetadata = ..., IProgress<ProgressNotificationValue> progress = ..., RequestOptions options = ..., CancellationToken cancellationToken = ...)`
  - `ValueTask<CallToolResult> CallToolAsync(string toolName, IReadOnlyDictionary<string, object> arguments = ..., IProgress<ProgressNotificationValue> progress = ..., RequestOptions options = ..., CancellationToken cancellationToken = ...)`
  - `ValueTask<CallToolResult> CallToolAsync(CallToolRequestParams requestParams, CancellationToken cancellationToken = ...)`
  - `ValueTask<McpTask> CancelTaskAsync(string taskId, RequestOptions options = ..., CancellationToken cancellationToken = ...)`
  - `ValueTask<CompleteResult> CompleteAsync(Reference reference, string argumentName, string argumentValue, RequestOptions options = ..., CancellationToken cancellationToken = ...)`
  - `ValueTask<CompleteResult> CompleteAsync(CompleteRequestParams requestParams, CancellationToken cancellationToken = ...)`
  - `Task<McpClient> CreateAsync(IClientTransport clientTransport, McpClientOptions clientOptions = ..., ILoggerFactory loggerFactory = ..., CancellationToken cancellationToken = ...)`
  - `ValueTask<GetPromptResult> GetPromptAsync(string name, IReadOnlyDictionary<string, object> arguments = ..., RequestOptions options = ..., CancellationToken cancellationToken = ...)`
  - `ValueTask<GetPromptResult> GetPromptAsync(GetPromptRequestParams requestParams, CancellationToken cancellationToken = ...)`
  - `ValueTask<McpTask> GetTaskAsync(string taskId, RequestOptions options = ..., CancellationToken cancellationToken = ...)`
  - `ValueTask<JsonElement> GetTaskResultAsync(string taskId, RequestOptions options = ..., CancellationToken cancellationToken = ...)`
  - `ValueTask<IList<McpClientPrompt>> ListPromptsAsync(RequestOptions options = ..., CancellationToken cancellationToken = ...)`
  - `ValueTask<ListPromptsResult> ListPromptsAsync(ListPromptsRequestParams requestParams, CancellationToken cancellationToken = ...)`
  - `ValueTask<IList<McpClientResourceTemplate>> ListResourceTemplatesAsync(RequestOptions options = ..., CancellationToken cancellationToken = ...)`
  - `ValueTask<ListResourceTemplatesResult> ListResourceTemplatesAsync(ListResourceTemplatesRequestParams requestParams, CancellationToken cancellationToken = ...)`
  - `ValueTask<IList<McpClientResource>> ListResourcesAsync(RequestOptions options = ..., CancellationToken cancellationToken = ...)`
  - `ValueTask<ListResourcesResult> ListResourcesAsync(ListResourcesRequestParams requestParams, CancellationToken cancellationToken = ...)`
  - `ValueTask<IList<McpTask>> ListTasksAsync(RequestOptions options = ..., CancellationToken cancellationToken = ...)`
  - `ValueTask<ListTasksResult> ListTasksAsync(ListTasksRequestParams requestParams, CancellationToken cancellationToken = ...)`
  - `ValueTask<IList<McpClientTool>> ListToolsAsync(RequestOptions options = ..., CancellationToken cancellationToken = ...)`
  - `ValueTask<ListToolsResult> ListToolsAsync(ListToolsRequestParams requestParams, CancellationToken cancellationToken = ...)`
  - `ValueTask<PingResult> PingAsync(RequestOptions options = ..., CancellationToken cancellationToken = ...)`
  - `ValueTask<PingResult> PingAsync(PingRequestParams requestParams, CancellationToken cancellationToken = ...)`
  - `ValueTask<McpTask> PollTaskUntilCompleteAsync(string taskId, RequestOptions options = ..., CancellationToken cancellationToken = ...)`
  - `ValueTask<ReadResourceResult> ReadResourceAsync(Uri uri, RequestOptions options = ..., CancellationToken cancellationToken = ...)`
  - `ValueTask<ReadResourceResult> ReadResourceAsync(string uri, RequestOptions options = ..., CancellationToken cancellationToken = ...)`
  - `ValueTask<ReadResourceResult> ReadResourceAsync(string uriTemplate, IReadOnlyDictionary<string, object> arguments, RequestOptions options = ..., CancellationToken cancellationToken = ...)`
  - `ValueTask<ReadResourceResult> ReadResourceAsync(ReadResourceRequestParams requestParams, CancellationToken cancellationToken = ...)`
  - `Task<McpClient> ResumeSessionAsync(IClientTransport clientTransport, ResumeClientSessionOptions resumeOptions, McpClientOptions clientOptions = ..., ILoggerFactory loggerFactory = ..., CancellationToken cancellationToken = ...)`
  - `Task SetLoggingLevelAsync(LogLevel level, RequestOptions options = ..., CancellationToken cancellationToken = ...)`
  - `Task SetLoggingLevelAsync(LoggingLevel level, RequestOptions options = ..., CancellationToken cancellationToken = ...)`
  - `Task SetLoggingLevelAsync(SetLevelRequestParams requestParams, CancellationToken cancellationToken = ...)`
  - `Task SubscribeToResourceAsync(Uri uri, RequestOptions options = ..., CancellationToken cancellationToken = ...)`
  - `Task SubscribeToResourceAsync(string uri, RequestOptions options = ..., CancellationToken cancellationToken = ...)`
  - `Task SubscribeToResourceAsync(SubscribeRequestParams requestParams, CancellationToken cancellationToken = ...)`
  - `Task<IAsyncDisposable> SubscribeToResourceAsync(Uri uri, Func<ResourceUpdatedNotificationParams, CancellationToken, ValueTask> handler, RequestOptions options = ..., CancellationToken cancellationToken = ...)`
  - `Task<IAsyncDisposable> SubscribeToResourceAsync(string uri, Func<ResourceUpdatedNotificationParams, CancellationToken, ValueTask> handler, RequestOptions options = ..., CancellationToken cancellationToken = ...)`
  - `Task UnsubscribeFromResourceAsync(Uri uri, RequestOptions options = ..., CancellationToken cancellationToken = ...)`
  - `Task UnsubscribeFromResourceAsync(string uri, RequestOptions options = ..., CancellationToken cancellationToken = ...)`
  - `Task UnsubscribeFromResourceAsync(UnsubscribeRequestParams requestParams, CancellationToken cancellationToken = ...)`
  - `Task<ClientCompletionDetails> Completion { get; }`
  - `ServerCapabilities ServerCapabilities { get; }`
  - `Implementation ServerInfo { get; }`
  - `string ServerInstructions { get; }`

`class McpClientHandlers`
  - `McpClientHandlers()`
  - `Func<ElicitRequestParams, CancellationToken, ValueTask<ElicitResult>> ElicitationHandler { get; set; }`
  - `IEnumerable<KeyValuePair<string, Func<JsonRpcNotification, CancellationToken, ValueTask>>> NotificationHandlers { get; set; }`
  - `Func<ListRootsRequestParams, CancellationToken, ValueTask<ListRootsResult>> RootsHandler { get; set; }`
  - `Func<CreateMessageRequestParams, IProgress<ProgressNotificationValue>, CancellationToken, ValueTask<CreateMessageResult>> SamplingHandler { get; set; }`
  - `Func<McpTask, CancellationToken, ValueTask> TaskStatusHandler { get; set; }`

`class McpClientOptions`
  - `McpClientOptions()`
  - `ClientCapabilities Capabilities { get; set; }`
  - `Implementation ClientInfo { get; set; }`
  - `McpClientHandlers Handlers { get; set; }`
  - `TimeSpan InitializationTimeout { get; set; }`
  - `string ProtocolVersion { get; set; }`
  - `bool SendTaskStatusNotifications { get; set; }`
  - `IMcpTaskStore TaskStore { get; set; }`

`class McpClientPrompt`
  - `McpClientPrompt(McpClient client, Prompt prompt)`
  - `ValueTask<GetPromptResult> GetAsync(IEnumerable<KeyValuePair<string, object>> arguments = ..., RequestOptions options = ..., CancellationToken cancellationToken = ...)`
  - `string Description { get; }`
  - `string Name { get; }`
  - `Prompt ProtocolPrompt { get; }`
  - `string Title { get; }`

`class McpClientResource`
  - `McpClientResource(McpClient client, Resource resource)`
  - `ValueTask<ReadResourceResult> ReadAsync(RequestOptions options = ..., CancellationToken cancellationToken = ...)`
  - `string Description { get; }`
  - `string MimeType { get; }`
  - `string Name { get; }`
  - `Resource ProtocolResource { get; }`
  - `string Title { get; }`
  - `string Uri { get; }`

`class McpClientResourceTemplate`
  - `McpClientResourceTemplate(McpClient client, ResourceTemplate resourceTemplate)`
  - `ValueTask<ReadResourceResult> ReadAsync(IReadOnlyDictionary<string, object> arguments, RequestOptions options = ..., CancellationToken cancellationToken = ...)`
  - `string Description { get; }`
  - `string MimeType { get; }`
  - `string Name { get; }`
  - `ResourceTemplate ProtocolResourceTemplate { get; }`
  - `string Title { get; }`
  - `string UriTemplate { get; }`

`class ResumeClientSessionOptions`
  - `ResumeClientSessionOptions()`
  - `string NegotiatedProtocolVersion { get; set; }`
  - `ServerCapabilities ServerCapabilities { get; set; }`
  - `Implementation ServerInfo { get; set; }`
  - `string ServerInstructions { get; set; }`

`class StdioClientCompletionDetails`
  - `StdioClientCompletionDetails()`
  - `Nullable<int> ExitCode { get; set; }`
  - `Nullable<int> ProcessId { get; set; }`
  - `IReadOnlyList<string> StandardErrorTail { get; set; }`

`class StdioClientTransport`
  - `StdioClientTransport(StdioClientTransportOptions options, ILoggerFactory loggerFactory = ...)`
  - `Task<ITransport> ConnectAsync(CancellationToken cancellationToken = ...)`
  - `string Name { get; }`

`class StdioClientTransportOptions`
  - `StdioClientTransportOptions()`
  - `Dictionary<string, string> GetDefaultEnvironmentVariables()`
  - `IList<string> Arguments { get; set; }`
  - `string Command { get; set; }`
  - `IDictionary<string, string> EnvironmentVariables { get; set; }`
  - `bool InheritEnvironmentVariables { get; set; }`
  - `string Name { get; set; }`
  - `TimeSpan ShutdownTimeout { get; set; }`
  - `Action<string> StandardErrorLines { get; set; }`
  - `string WorkingDirectory { get; set; }`

`interface IMcpTaskStore`
  - `Task<McpTask> CancelTaskAsync(string taskId, string sessionId = ..., CancellationToken cancellationToken = ...)`
  - `Task<McpTask> CreateTaskAsync(McpTaskMetadata taskParams, RequestId requestId, JsonRpcRequest request, string sessionId = ..., CancellationToken cancellationToken = ...)`
  - `Task<McpTask> GetTaskAsync(string taskId, string sessionId = ..., CancellationToken cancellationToken = ...)`
  - `Task<JsonElement> GetTaskResultAsync(string taskId, string sessionId = ..., CancellationToken cancellationToken = ...)`
  - `Task<ListTasksResult> ListTasksAsync(string cursor = ..., string sessionId = ..., CancellationToken cancellationToken = ...)`
  - `Task<McpTask> StoreTaskResultAsync(string taskId, McpTaskStatus status, JsonElement result, string sessionId = ..., CancellationToken cancellationToken = ...)`
  - `Task<McpTask> UpdateTaskStatusAsync(string taskId, McpTaskStatus status, string statusMessage, string sessionId = ..., CancellationToken cancellationToken = ...)`

`class InMemoryMcpTaskStore`
  - `InMemoryMcpTaskStore(Nullable<TimeSpan> defaultTtl = ..., Nullable<TimeSpan> maxTtl = ..., Nullable<TimeSpan> pollInterval = ..., Nullable<TimeSpan> cleanupInterval = ..., int pageSize = ..., Nullable<int> maxTasks = ..., Nullable<int> maxTasksPerSession = ...)`
  - `Task<McpTask> CancelTaskAsync(string taskId, string sessionId = ..., CancellationToken cancellationToken = ...)`
  - `Task<McpTask> CreateTaskAsync(McpTaskMetadata taskParams, RequestId requestId, JsonRpcRequest request, string sessionId = ..., CancellationToken cancellationToken = ...)`
  - `void Dispose()`
  - `Task<McpTask> GetTaskAsync(string taskId, string sessionId = ..., CancellationToken cancellationToken = ...)`
  - `Task<JsonElement> GetTaskResultAsync(string taskId, string sessionId = ..., CancellationToken cancellationToken = ...)`
  - `Task<ListTasksResult> ListTasksAsync(string cursor = ..., string sessionId = ..., CancellationToken cancellationToken = ...)`
  - `Task<McpTask> StoreTaskResultAsync(string taskId, McpTaskStatus status, JsonElement result, string sessionId = ..., CancellationToken cancellationToken = ...)`
  - `Task<McpTask> UpdateTaskStatusAsync(string taskId, McpTaskStatus status, string statusMessage, string sessionId = ..., CancellationToken cancellationToken = ...)`

`enum McpErrorCode`
  - `values: ResourceNotFound, UrlElicitationRequired, InvalidRequest, MethodNotFound, InvalidParams, InternalError, ParseError`

`class McpException`
  - `McpException()`
  - `McpException(string message)`
  - `McpException(string message, Exception innerException)`

`class McpJsonUtilities`
  - `JsonSerializerOptions DefaultOptions { get; }`

`class McpProtocolException`
  - `McpProtocolException()`
  - `McpProtocolException(string message)`
  - `McpProtocolException(string message, Exception innerException)`
  - `McpProtocolException(string message, McpErrorCode errorCode)`
  - `McpProtocolException(string message, Exception innerException, McpErrorCode errorCode)`
  - `McpErrorCode ErrorCode { get; }`

`class McpSession`
  - `ValueTask DisposeAsync()`
  - `Task NotifyProgressAsync(ProgressToken progressToken, ProgressNotificationValue progress, RequestOptions options = ..., CancellationToken cancellationToken = ...)`
  - `Task NotifyProgressAsync(ProgressNotificationParams requestParams, CancellationToken cancellationToken = ...)`
  - `IAsyncDisposable RegisterNotificationHandler(string method, Func<JsonRpcNotification, CancellationToken, ValueTask> handler)`
  - `Task SendMessageAsync(JsonRpcMessage message, CancellationToken cancellationToken = ...)`
  - `Task SendNotificationAsync(string method, CancellationToken cancellationToken = ...)`
  - `Task SendNotificationAsync<TParameters>(string method, TParameters parameters, JsonSerializerOptions serializerOptions = ..., CancellationToken cancellationToken = ...)`
  - `Task<JsonRpcResponse> SendRequestAsync(JsonRpcRequest request, CancellationToken cancellationToken = ...)`
  - `ValueTask<TResult> SendRequestAsync<TParameters, TResult>(string method, TParameters parameters, JsonSerializerOptions serializerOptions = ..., RequestId requestId = ..., CancellationToken cancellationToken = ...)`
  - `string NegotiatedProtocolVersion { get; }`
  - `string SessionId { get; }`

`class ProgressNotificationValue`
  - `ProgressNotificationValue()`
  - `string Message { get; set; }`
  - `float Progress { get; set; }`
  - `Nullable<float> Total { get; set; }`

`class Annotations`
  - `Annotations()`
  - `IList<Role> Audience { get; set; }`
  - `Nullable<DateTimeOffset> LastModified { get; set; }`
  - `Nullable<float> Priority { get; set; }`

`class Argument`
  - `Argument()`
  - `string Name { get; set; }`
  - `string Value { get; set; }`

`class AudioContentBlock`
  - `AudioContentBlock()`
  - `AudioContentBlock FromBytes(ReadOnlyMemory<byte> bytes, string mimeType)`
  - `ReadOnlyMemory<byte> Data { get; set; }`
  - `ReadOnlyMemory<byte> DecodedData { get; }`
  - `string MimeType { get; set; }`
  - `string Type { get; }`

`class BlobResourceContents`
  - `BlobResourceContents()`
  - `BlobResourceContents FromBytes(ReadOnlyMemory<byte> bytes, string uri, string mimeType = ...)`
  - `ReadOnlyMemory<byte> Blob { get; set; }`
  - `ReadOnlyMemory<byte> DecodedData { get; }`

`class CallToolMcpTasksCapability`
  - `CallToolMcpTasksCapability()`

`class CallToolRequestParams`
  - `CallToolRequestParams()`
  - `IDictionary<string, JsonElement> Arguments { get; set; }`
  - `string Name { get; set; }`
  - `McpTaskMetadata Task { get; set; }`

`class CallToolResult`
  - `CallToolResult()`
  - `IList<ContentBlock> Content { get; set; }`
  - `Nullable<bool> IsError { get; set; }`
  - `Nullable<JsonElement> StructuredContent { get; set; }`
  - `McpTask Task { get; set; }`

`class CancelMcpTaskRequestParams`
  - `CancelMcpTaskRequestParams()`
  - `string TaskId { get; set; }`

`class CancelMcpTaskResult`
  - `CancelMcpTaskResult()`
  - `DateTimeOffset CreatedAt { get; set; }`
  - `DateTimeOffset LastUpdatedAt { get; set; }`
  - `Nullable<TimeSpan> PollInterval { get; set; }`
  - `McpTaskStatus Status { get; set; }`
  - `string StatusMessage { get; set; }`
  - `string TaskId { get; set; }`
  - `Nullable<TimeSpan> TimeToLive { get; set; }`

`class CancelMcpTasksCapability`
  - `CancelMcpTasksCapability()`

`class CancelledNotificationParams`
  - `CancelledNotificationParams()`
  - `string Reason { get; set; }`
  - `RequestId RequestId { get; set; }`

`class ClientCapabilities`
  - `ClientCapabilities()`
  - `ElicitationCapability Elicitation { get; set; }`
  - `IDictionary<string, object> Experimental { get; set; }`
  - `IDictionary<string, object> Extensions { get; set; }`
  - `RootsCapability Roots { get; set; }`
  - `SamplingCapability Sampling { get; set; }`
  - `McpTasksCapability Tasks { get; set; }`

`class CompleteContext`
  - `CompleteContext()`
  - `IDictionary<string, string> Arguments { get; set; }`

`class CompleteRequestParams`
  - `CompleteRequestParams()`
  - `Argument Argument { get; set; }`
  - `CompleteContext Context { get; set; }`
  - `Reference Ref { get; set; }`

`class CompleteResult`
  - `CompleteResult()`
  - `Completion Completion { get; set; }`

`class Completion`
  - `Completion()`
  - `Nullable<bool> HasMore { get; set; }`
  - `Nullable<int> Total { get; set; }`
  - `IList<string> Values { get; set; }`

`class CompletionsCapability`
  - `CompletionsCapability()`

`class ContentBlock`
  - `Annotations Annotations { get; set; }`
  - `JsonObject Meta { get; set; }`
  - `string Type { get; }`

`enum ContextInclusion`
  - `values: None, ThisServer, AllServers`

`class CreateElicitationMcpTasksCapability`
  - `CreateElicitationMcpTasksCapability()`

`class CreateMessageMcpTasksCapability`
  - `CreateMessageMcpTasksCapability()`

`class CreateMessageRequestParams`
  - `CreateMessageRequestParams()`
  - `Nullable<ContextInclusion> IncludeContext { get; set; }`
  - `int MaxTokens { get; set; }`
  - `IList<SamplingMessage> Messages { get; set; }`
  - `JsonObject Metadata { get; set; }`
  - `ModelPreferences ModelPreferences { get; set; }`
  - `IList<string> StopSequences { get; set; }`
  - `string SystemPrompt { get; set; }`
  - `McpTaskMetadata Task { get; set; }`
  - `Nullable<float> Temperature { get; set; }`
  - `ToolChoice ToolChoice { get; set; }`
  - `IList<Tool> Tools { get; set; }`

`class CreateMessageResult`
  - `CreateMessageResult()`
  - `IList<ContentBlock> Content { get; set; }`
  - `string Model { get; set; }`
  - `Role Role { get; set; }`
  - `string StopReason { get; set; }`

`class CreateTaskResult`
  - `CreateTaskResult()`
  - `McpTask Task { get; set; }`

`class ElicitRequestParams`
  - `ElicitRequestParams()`
  - `string ElicitationId { get; set; }`
  - `string Message { get; set; }`
  - `string Mode { get; set; }`
  - `RequestSchema RequestedSchema { get; set; }`
  - `McpTaskMetadata Task { get; set; }`
  - `string Url { get; set; }`

`class ElicitResult`
  - `ElicitResult()`
  - `string Action { get; set; }`
  - `IDictionary<string, JsonElement> Content { get; set; }`
  - `bool IsAccepted { get; }`

`class ElicitResult<T>`
  - `ElicitResult`1()`
  - `string Action { get; set; }`
  - `T Content { get; set; }`
  - `bool IsAccepted { get; }`

`class ElicitationCapability`
  - `ElicitationCapability()`
  - `FormElicitationCapability Form { get; set; }`
  - `UrlElicitationCapability Url { get; set; }`

`class ElicitationCompleteNotificationParams`
  - `ElicitationCompleteNotificationParams()`
  - `string ElicitationId { get; set; }`

`class ElicitationMcpTasksCapability`
  - `ElicitationMcpTasksCapability()`
  - `CreateElicitationMcpTasksCapability Create { get; set; }`

`class EmbeddedResourceBlock`
  - `EmbeddedResourceBlock()`
  - `ResourceContents Resource { get; set; }`
  - `string Type { get; }`

`class EmptyResult`
  - `EmptyResult()`

`class FormElicitationCapability`
  - `FormElicitationCapability()`

`class GetPromptRequestParams`
  - `GetPromptRequestParams()`
  - `IDictionary<string, JsonElement> Arguments { get; set; }`
  - `string Name { get; set; }`

`class GetPromptResult`
  - `GetPromptResult()`
  - `string Description { get; set; }`
  - `IList<PromptMessage> Messages { get; set; }`

`class GetTaskPayloadRequestParams`
  - `GetTaskPayloadRequestParams()`
  - `string TaskId { get; set; }`

`class GetTaskRequestParams`
  - `GetTaskRequestParams()`
  - `string TaskId { get; set; }`

`class GetTaskResult`
  - `GetTaskResult()`
  - `DateTimeOffset CreatedAt { get; set; }`
  - `DateTimeOffset LastUpdatedAt { get; set; }`
  - `Nullable<TimeSpan> PollInterval { get; set; }`
  - `McpTaskStatus Status { get; set; }`
  - `string StatusMessage { get; set; }`
  - `string TaskId { get; set; }`
  - `Nullable<TimeSpan> TimeToLive { get; set; }`

`interface IBaseMetadata`
  - `string Name { get; set; }`
  - `string Title { get; set; }`

`interface ITransport`
  - `Task SendMessageAsync(JsonRpcMessage message, CancellationToken cancellationToken = ...)`
  - `ChannelReader<JsonRpcMessage> MessageReader { get; }`
  - `string SessionId { get; }`

`class Icon`
  - `Icon()`
  - `string MimeType { get; set; }`
  - `IList<string> Sizes { get; set; }`
  - `string Source { get; set; }`
  - `string Theme { get; set; }`

`class ImageContentBlock`
  - `ImageContentBlock()`
  - `ImageContentBlock FromBytes(ReadOnlyMemory<byte> bytes, string mimeType)`
  - `ReadOnlyMemory<byte> Data { get; set; }`
  - `ReadOnlyMemory<byte> DecodedData { get; }`
  - `string MimeType { get; set; }`
  - `string Type { get; }`

`class Implementation`
  - `Implementation()`
  - `string Description { get; set; }`
  - `IList<Icon> Icons { get; set; }`
  - `string Name { get; set; }`
  - `string Title { get; set; }`
  - `string Version { get; set; }`
  - `string WebsiteUrl { get; set; }`

`class InitializeRequestParams`
  - `InitializeRequestParams()`
  - `ClientCapabilities Capabilities { get; set; }`
  - `Implementation ClientInfo { get; set; }`
  - `string ProtocolVersion { get; set; }`

`class InitializeResult`
  - `InitializeResult()`
  - `ServerCapabilities Capabilities { get; set; }`
  - `string Instructions { get; set; }`
  - `string ProtocolVersion { get; set; }`
  - `Implementation ServerInfo { get; set; }`

`class InitializedNotificationParams`
  - `InitializedNotificationParams()`

`class JsonRpcError`
  - `JsonRpcError()`
  - `JsonRpcErrorDetail Error { get; set; }`

`class JsonRpcErrorDetail`
  - `JsonRpcErrorDetail()`
  - `int Code { get; set; }`
  - `object Data { get; set; }`
  - `string Message { get; set; }`

`class JsonRpcMessage`
  - `JsonRpcMessageContext Context { get; set; }`
  - `string JsonRpc { get; set; }`

`class JsonRpcMessageContext`
  - `JsonRpcMessageContext()`
  - `ExecutionContext ExecutionContext { get; set; }`
  - `IDictionary<string, object> Items { get; set; }`
  - `ITransport RelatedTransport { get; set; }`
  - `ClaimsPrincipal User { get; set; }`

`class JsonRpcMessageWithId`
  - `RequestId Id { get; set; }`

`class JsonRpcNotification`
  - `JsonRpcNotification()`
  - `string Method { get; set; }`
  - `JsonNode Params { get; set; }`

`class JsonRpcRequest`
  - `JsonRpcRequest()`
  - `string Method { get; set; }`
  - `JsonNode Params { get; set; }`

`class JsonRpcResponse`
  - `JsonRpcResponse()`
  - `JsonNode Result { get; set; }`

`class ListMcpTasksCapability`
  - `ListMcpTasksCapability()`

`class ListPromptsRequestParams`
  - `ListPromptsRequestParams()`

`class ListPromptsResult`
  - `ListPromptsResult()`
  - `IList<Prompt> Prompts { get; set; }`

`class ListResourceTemplatesRequestParams`
  - `ListResourceTemplatesRequestParams()`

`class ListResourceTemplatesResult`
  - `ListResourceTemplatesResult()`
  - `IList<ResourceTemplate> ResourceTemplates { get; set; }`

`class ListResourcesRequestParams`
  - `ListResourcesRequestParams()`

`class ListResourcesResult`
  - `ListResourcesResult()`
  - `IList<Resource> Resources { get; set; }`

`class ListRootsRequestParams`
  - `ListRootsRequestParams()`

`class ListRootsResult`
  - `ListRootsResult()`
  - `IList<Root> Roots { get; set; }`

`class ListTasksRequestParams`
  - `ListTasksRequestParams()`

`class ListTasksResult`
  - `ListTasksResult()`
  - `IList<McpTask> Tasks { get; set; }`

`class ListToolsRequestParams`
  - `ListToolsRequestParams()`

`class ListToolsResult`
  - `ListToolsResult()`
  - `IList<Tool> Tools { get; set; }`

`class LoggingCapability`
  - `LoggingCapability()`

`enum LoggingLevel`
  - `values: Debug, Info, Notice, Warning, Error, Critical, Alert, Emergency`

`class LoggingMessageNotificationParams`
  - `LoggingMessageNotificationParams()`
  - `JsonElement Data { get; set; }`
  - `LoggingLevel Level { get; set; }`
  - `string Logger { get; set; }`

`class McpTask`
  - `McpTask()`
  - `DateTimeOffset CreatedAt { get; set; }`
  - `DateTimeOffset LastUpdatedAt { get; set; }`
  - `Nullable<TimeSpan> PollInterval { get; set; }`
  - `McpTaskStatus Status { get; set; }`
  - `string StatusMessage { get; set; }`
  - `string TaskId { get; set; }`
  - `Nullable<TimeSpan> TimeToLive { get; set; }`

`class McpTaskMetadata`
  - `McpTaskMetadata()`
  - `Nullable<TimeSpan> TimeToLive { get; set; }`

`enum McpTaskStatus`
  - `values: Working, InputRequired, Completed, Failed, Cancelled`

`class McpTaskStatusNotificationParams`
  - `McpTaskStatusNotificationParams()`
  - `DateTimeOffset CreatedAt { get; set; }`
  - `DateTimeOffset LastUpdatedAt { get; set; }`
  - `Nullable<TimeSpan> PollInterval { get; set; }`
  - `McpTaskStatus Status { get; set; }`
  - `string StatusMessage { get; set; }`
  - `string TaskId { get; set; }`
  - `Nullable<TimeSpan> TimeToLive { get; set; }`

`class McpTasksCapability`
  - `McpTasksCapability()`
  - `CancelMcpTasksCapability Cancel { get; set; }`
  - `ListMcpTasksCapability List { get; set; }`
  - `RequestMcpTasksCapability Requests { get; set; }`

`class ModelHint`
  - `ModelHint()`
  - `string Name { get; set; }`

`class ModelPreferences`
  - `ModelPreferences()`
  - `Nullable<float> CostPriority { get; set; }`
  - `IList<ModelHint> Hints { get; set; }`
  - `Nullable<float> IntelligencePriority { get; set; }`
  - `Nullable<float> SpeedPriority { get; set; }`

`class NotificationParams`
  - `JsonObject Meta { get; set; }`

`class PaginatedRequestParams`
  - `string Cursor { get; set; }`

`class PaginatedResult`
  - `string NextCursor { get; set; }`

`class PingRequestParams`
  - `PingRequestParams()`

`class PingResult`
  - `PingResult()`

`class ProgressNotificationParams`
  - `ProgressNotificationParams()`
  - `ProgressNotificationValue Progress { get; set; }`
  - `ProgressToken ProgressToken { get; set; }`

`struct ProgressToken`
  - `ProgressToken(string value)`
  - `ProgressToken(long value)`
  - `bool Equals(ProgressToken other)`
  - `bool Equals(object obj)`
  - `int GetHashCode()`
  - `string ToString()`
  - `object Token { get; }`

`class Prompt`
  - `Prompt()`
  - `IList<PromptArgument> Arguments { get; set; }`
  - `string Description { get; set; }`
  - `IList<Icon> Icons { get; set; }`
  - `JsonObject Meta { get; set; }`
  - `string Name { get; set; }`
  - `string Title { get; set; }`

`class PromptArgument`
  - `PromptArgument()`
  - `string Description { get; set; }`
  - `string Name { get; set; }`
  - `Nullable<bool> Required { get; set; }`
  - `string Title { get; set; }`

`class PromptListChangedNotificationParams`
  - `PromptListChangedNotificationParams()`

`class PromptMessage`
  - `PromptMessage()`
  - `ContentBlock Content { get; set; }`
  - `Role Role { get; set; }`

`class PromptReference`
  - `PromptReference()`
  - `string ToString()`
  - `string Name { get; set; }`
  - `string Title { get; set; }`
  - `string Type { get; }`

`class PromptsCapability`
  - `PromptsCapability()`
  - `Nullable<bool> ListChanged { get; set; }`

`class ReadResourceRequestParams`
  - `ReadResourceRequestParams()`
  - `string Uri { get; set; }`

`class ReadResourceResult`
  - `ReadResourceResult()`
  - `IList<ResourceContents> Contents { get; set; }`

`class Reference`
  - `string Type { get; }`

`struct RequestId`
  - `RequestId(string value)`
  - `RequestId(long value)`
  - `bool Equals(RequestId other)`
  - `bool Equals(object obj)`
  - `int GetHashCode()`
  - `string ToString()`
  - `object Id { get; }`

`class RequestMcpTasksCapability`
  - `RequestMcpTasksCapability()`
  - `ElicitationMcpTasksCapability Elicitation { get; set; }`
  - `SamplingMcpTasksCapability Sampling { get; set; }`
  - `ToolsMcpTasksCapability Tools { get; set; }`

`class RequestParams`
  - `JsonObject Meta { get; set; }`
  - `Nullable<ProgressToken> ProgressToken { get; }`

`class RequestParamsMetadata`
  - `RequestParamsMetadata()`
  - `Nullable<ProgressToken> ProgressToken { get; set; }`

`class Resource`
  - `Resource()`
  - `Annotations Annotations { get; set; }`
  - `string Description { get; set; }`
  - `IList<Icon> Icons { get; set; }`
  - `JsonObject Meta { get; set; }`
  - `string MimeType { get; set; }`
  - `string Name { get; set; }`
  - `Nullable<long> Size { get; set; }`
  - `string Title { get; set; }`
  - `string Uri { get; set; }`

`class ResourceContents`
  - `JsonObject Meta { get; set; }`
  - `string MimeType { get; set; }`
  - `string Uri { get; set; }`

`class ResourceLinkBlock`
  - `ResourceLinkBlock()`
  - `string Description { get; set; }`
  - `IList<Icon> Icons { get; set; }`
  - `string MimeType { get; set; }`
  - `string Name { get; set; }`
  - `Nullable<long> Size { get; set; }`
  - `string Title { get; set; }`
  - `string Type { get; }`
  - `string Uri { get; set; }`

`class ResourceListChangedNotificationParams`
  - `ResourceListChangedNotificationParams()`

`class ResourceTemplate`
  - `ResourceTemplate()`
  - `Resource AsResource()`
  - `Annotations Annotations { get; set; }`
  - `string Description { get; set; }`
  - `IList<Icon> Icons { get; set; }`
  - `bool IsTemplated { get; }`
  - `JsonObject Meta { get; set; }`
  - `string MimeType { get; set; }`
  - `string Name { get; set; }`
  - `string Title { get; set; }`
  - `string UriTemplate { get; set; }`

`class ResourceTemplateReference`
  - `ResourceTemplateReference()`
  - `string ToString()`
  - `string Type { get; }`
  - `string Uri { get; set; }`

`class ResourceUpdatedNotificationParams`
  - `ResourceUpdatedNotificationParams()`
  - `string Uri { get; set; }`

`class ResourcesCapability`
  - `ResourcesCapability()`
  - `Nullable<bool> ListChanged { get; set; }`
  - `Nullable<bool> Subscribe { get; set; }`

`class Result`
  - `JsonObject Meta { get; set; }`

`enum Role`
  - `values: User, Assistant`

`class Root`
  - `Root()`
  - `JsonObject Meta { get; set; }`
  - `string Name { get; set; }`
  - `string Uri { get; set; }`

`class RootsCapability`
  - `RootsCapability()`
  - `Nullable<bool> ListChanged { get; set; }`

`class RootsListChangedNotificationParams`
  - `RootsListChangedNotificationParams()`

`class SamplingCapability`
  - `SamplingCapability()`
  - `SamplingContextCapability Context { get; set; }`
  - `SamplingToolsCapability Tools { get; set; }`

`class SamplingContextCapability`
  - `SamplingContextCapability()`

`class SamplingMcpTasksCapability`
  - `SamplingMcpTasksCapability()`
  - `CreateMessageMcpTasksCapability CreateMessage { get; set; }`

`class SamplingMessage`
  - `SamplingMessage()`
  - `IList<ContentBlock> Content { get; set; }`
  - `JsonObject Meta { get; set; }`
  - `Role Role { get; set; }`

`class SamplingToolsCapability`
  - `SamplingToolsCapability()`

`class ServerCapabilities`
  - `ServerCapabilities()`
  - `CompletionsCapability Completions { get; set; }`
  - `IDictionary<string, object> Experimental { get; set; }`
  - `IDictionary<string, object> Extensions { get; set; }`
  - `LoggingCapability Logging { get; set; }`
  - `PromptsCapability Prompts { get; set; }`
  - `ResourcesCapability Resources { get; set; }`
  - `McpTasksCapability Tasks { get; set; }`
  - `ToolsCapability Tools { get; set; }`

`class SetLevelRequestParams`
  - `SetLevelRequestParams()`
  - `LoggingLevel Level { get; set; }`

`class SingleItemOrListConverter<T>`
  - `SingleItemOrListConverter`1()`
  - `IList<T> Read(Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)`
  - `void Write(Utf8JsonWriter writer, IList<T> value, JsonSerializerOptions options)`

`class StreamClientTransport`
  - `StreamClientTransport(Stream serverInput, Stream serverOutput, ILoggerFactory loggerFactory = ...)`
  - `Task<ITransport> ConnectAsync(CancellationToken cancellationToken = ...)`
  - `string Name { get; }`

`class SubscribeRequestParams`
  - `SubscribeRequestParams()`
  - `string Uri { get; set; }`

`class TextContentBlock`
  - `TextContentBlock()`
  - `string ToString()`
  - `string Text { get; set; }`
  - `string Type { get; }`

`class TextResourceContents`
  - `TextResourceContents()`
  - `string ToString()`
  - `string Text { get; set; }`

`class TimeSpanMillisecondsConverter`
  - `TimeSpanMillisecondsConverter()`
  - `TimeSpan Read(Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)`
  - `void Write(Utf8JsonWriter writer, TimeSpan value, JsonSerializerOptions options)`

`class Tool`
  - `Tool()`
  - `ToolAnnotations Annotations { get; set; }`
  - `string Description { get; set; }`
  - `ToolExecution Execution { get; set; }`
  - `IList<Icon> Icons { get; set; }`
  - `JsonElement InputSchema { get; set; }`
  - `JsonObject Meta { get; set; }`
  - `string Name { get; set; }`
  - `Nullable<JsonElement> OutputSchema { get; set; }`
  - `string Title { get; set; }`

`class ToolAnnotations`
  - `ToolAnnotations()`
  - `Nullable<bool> DestructiveHint { get; set; }`
  - `Nullable<bool> IdempotentHint { get; set; }`
  - `Nullable<bool> OpenWorldHint { get; set; }`
  - `Nullable<bool> ReadOnlyHint { get; set; }`
  - `string Title { get; set; }`

`class ToolChoice`
  - `ToolChoice()`
  - `string Mode { get; set; }`

`class ToolExecution`
  - `ToolExecution()`
  - `Nullable<ToolTaskSupport> TaskSupport { get; set; }`

`class ToolListChangedNotificationParams`
  - `ToolListChangedNotificationParams()`

`class ToolResultContentBlock`
  - `ToolResultContentBlock()`
  - `IList<ContentBlock> Content { get; set; }`
  - `Nullable<bool> IsError { get; set; }`
  - `Nullable<JsonElement> StructuredContent { get; set; }`
  - `string ToolUseId { get; set; }`
  - `string Type { get; }`

`enum ToolTaskSupport`
  - `values: Forbidden, Optional, Required`

`class ToolUseContentBlock`
  - `ToolUseContentBlock()`
  - `string Id { get; set; }`
  - `JsonElement Input { get; set; }`
  - `string Name { get; set; }`
  - `string Type { get; }`

`class ToolsCapability`
  - `ToolsCapability()`
  - `Nullable<bool> ListChanged { get; set; }`

`class ToolsMcpTasksCapability`
  - `ToolsMcpTasksCapability()`
  - `CallToolMcpTasksCapability Call { get; set; }`

`class TransportBase`
  - `ValueTask DisposeAsync()`
  - `Task SendMessageAsync(JsonRpcMessage message, CancellationToken cancellationToken = ...)`
  - `bool IsConnected { get; }`
  - `ChannelReader<JsonRpcMessage> MessageReader { get; }`
  - `string SessionId { get; set; }`

`class UnsubscribeRequestParams`
  - `UnsubscribeRequestParams()`
  - `string Uri { get; set; }`

`class UrlElicitationCapability`
  - `UrlElicitationCapability()`

`class UrlElicitationRequiredErrorData`
  - `UrlElicitationRequiredErrorData()`
  - `IList<ElicitRequestParams> Elicitations { get; set; }`

`class RequestOptions`
  - `RequestOptions()`
  - `JsonObject GetMetaForRequest()`
  - `JsonSerializerOptions JsonSerializerOptions { get; set; }`
  - `JsonObject Meta { get; set; }`
  - `Nullable<ProgressToken> ProgressToken { get; set; }`

`class DelegatingMcpServerPrompt`
  - `ValueTask<GetPromptResult> GetAsync(RequestContext<GetPromptRequestParams> request, CancellationToken cancellationToken = ...)`
  - `string ToString()`
  - `IReadOnlyList<object> Metadata { get; }`
  - `Prompt ProtocolPrompt { get; }`

`class DelegatingMcpServerResource`
  - `bool IsMatch(string uri)`
  - `ValueTask<ReadResourceResult> ReadAsync(RequestContext<ReadResourceRequestParams> request, CancellationToken cancellationToken = ...)`
  - `string ToString()`
  - `IReadOnlyList<object> Metadata { get; }`
  - `Resource ProtocolResource { get; }`
  - `ResourceTemplate ProtocolResourceTemplate { get; }`

`class DelegatingMcpServerTool`
  - `ValueTask<CallToolResult> InvokeAsync(RequestContext<CallToolRequestParams> request, CancellationToken cancellationToken = ...)`
  - `string ToString()`
  - `IReadOnlyList<object> Metadata { get; }`
  - `Tool ProtocolTool { get; }`

`interface IMcpServerPrimitive`
  - `string Id { get; }`
  - `IReadOnlyList<object> Metadata { get; }`

`interface ISseEventStreamReader`
  - `IAsyncEnumerable<SseItem<JsonRpcMessage>> ReadEventsAsync(CancellationToken cancellationToken = ...)`
  - `string SessionId { get; }`
  - `string StreamId { get; }`

`interface ISseEventStreamStore`
  - `ValueTask<ISseEventStreamWriter> CreateStreamAsync(SseEventStreamOptions options, CancellationToken cancellationToken = ...)`
  - `ValueTask<ISseEventStreamReader> GetStreamReaderAsync(string lastEventId, CancellationToken cancellationToken = ...)`

`interface ISseEventStreamWriter`
  - `ValueTask SetModeAsync(SseEventStreamMode mode, CancellationToken cancellationToken = ...)`
  - `ValueTask<SseItem<JsonRpcMessage>> WriteEventAsync(SseItem<JsonRpcMessage> sseItem, CancellationToken cancellationToken = ...)`

`class McpMessageFilter`
  - `McpMessageFilter(object object, IntPtr method)`
  - `IAsyncResult BeginInvoke(McpMessageHandler next, AsyncCallback callback, object object)`
  - `McpMessageHandler EndInvoke(IAsyncResult result)`
  - `McpMessageHandler Invoke(McpMessageHandler next)`

`class McpMessageFilters`
  - `McpMessageFilters()`
  - `IList<McpMessageFilter> IncomingFilters { get; set; }`
  - `IList<McpMessageFilter> OutgoingFilters { get; set; }`

`class McpMessageHandler`
  - `McpMessageHandler(object object, IntPtr method)`
  - `IAsyncResult BeginInvoke(MessageContext context, CancellationToken cancellationToken, AsyncCallback callback, object object)`
  - `Task EndInvoke(IAsyncResult result)`
  - `Task Invoke(MessageContext context, CancellationToken cancellationToken)`

`class McpMetaAttribute`
  - `McpMetaAttribute(string name, string value = ...)`
  - `McpMetaAttribute(string name, double value)`
  - `McpMetaAttribute(string name, bool value)`
  - `string JsonValue { get; set; }`
  - `string Name { get; }`

`class McpRequestFilter<TParams, TResult>`
  - `McpRequestFilter`2(object object, IntPtr method)`
  - `IAsyncResult BeginInvoke(McpRequestHandler<TParams, TResult> next, AsyncCallback callback, object object)`
  - `McpRequestHandler<TParams, TResult> EndInvoke(IAsyncResult result)`
  - `McpRequestHandler<TParams, TResult> Invoke(McpRequestHandler<TParams, TResult> next)`

`class McpRequestFilters`
  - `McpRequestFilters()`
  - `IList<McpRequestFilter<CallToolRequestParams, CallToolResult>> CallToolFilters { get; set; }`
  - `IList<McpRequestFilter<CompleteRequestParams, CompleteResult>> CompleteFilters { get; set; }`
  - `IList<McpRequestFilter<GetPromptRequestParams, GetPromptResult>> GetPromptFilters { get; set; }`
  - `IList<McpRequestFilter<ListPromptsRequestParams, ListPromptsResult>> ListPromptsFilters { get; set; }`
  - `IList<McpRequestFilter<ListResourceTemplatesRequestParams, ListResourceTemplatesResult>> ListResourceTemplatesFilters { get; set; }`
  - `IList<McpRequestFilter<ListResourcesRequestParams, ListResourcesResult>> ListResourcesFilters { get; set; }`
  - `IList<McpRequestFilter<ListToolsRequestParams, ListToolsResult>> ListToolsFilters { get; set; }`
  - `IList<McpRequestFilter<ReadResourceRequestParams, ReadResourceResult>> ReadResourceFilters { get; set; }`
  - `IList<McpRequestFilter<SetLevelRequestParams, EmptyResult>> SetLoggingLevelFilters { get; set; }`
  - `IList<McpRequestFilter<SubscribeRequestParams, EmptyResult>> SubscribeToResourcesFilters { get; set; }`
  - `IList<McpRequestFilter<UnsubscribeRequestParams, EmptyResult>> UnsubscribeFromResourcesFilters { get; set; }`

`class McpRequestHandler<TParams, TResult>`
  - `McpRequestHandler`2(object object, IntPtr method)`
  - `IAsyncResult BeginInvoke(RequestContext<TParams> request, CancellationToken cancellationToken, AsyncCallback callback, object object)`
  - `ValueTask<TResult> EndInvoke(IAsyncResult result)`
  - `ValueTask<TResult> Invoke(RequestContext<TParams> request, CancellationToken cancellationToken)`

`class McpServer`
  - `ILoggerProvider AsClientLoggerProvider()`
  - `ValueTask<McpTask> CancelTaskAsync(string taskId, CancellationToken cancellationToken = ...)`
  - `McpServer Create(ITransport transport, McpServerOptions serverOptions, ILoggerFactory loggerFactory = ..., IServiceProvider serviceProvider = ...)`
  - `ValueTask<McpTask> ElicitAsTaskAsync(ElicitRequestParams requestParams, McpTaskMetadata taskMetadata, CancellationToken cancellationToken = ...)`
  - `ValueTask<ElicitResult> ElicitAsync(ElicitRequestParams requestParams, CancellationToken cancellationToken = ...)`
  - `ValueTask<ElicitResult<T>> ElicitAsync<T>(string message, RequestOptions options = ..., CancellationToken cancellationToken = ...)`
  - `ValueTask<McpTask> GetTaskAsync(string taskId, CancellationToken cancellationToken = ...)`
  - `ValueTask<TResult> GetTaskResultAsync<TResult>(string taskId, JsonSerializerOptions jsonSerializerOptions = ..., CancellationToken cancellationToken = ...)`
  - `ValueTask<IList<McpTask>> ListTasksAsync(CancellationToken cancellationToken = ...)`
  - `ValueTask<ListTasksResult> ListTasksAsync(ListTasksRequestParams requestParams, CancellationToken cancellationToken = ...)`
  - `Task NotifyTaskStatusAsync(McpTask task, CancellationToken cancellationToken = ...)`
  - `ValueTask<McpTask> PollTaskUntilCompleteAsync(string taskId, CancellationToken cancellationToken = ...)`
  - `ValueTask<ListRootsResult> RequestRootsAsync(ListRootsRequestParams requestParams, CancellationToken cancellationToken = ...)`
  - `Task RunAsync(CancellationToken cancellationToken = ...)`
  - `ValueTask<McpTask> SampleAsTaskAsync(CreateMessageRequestParams requestParams, McpTaskMetadata taskMetadata, CancellationToken cancellationToken = ...)`
  - `ValueTask<CreateMessageResult> SampleAsync(CreateMessageRequestParams requestParams, CancellationToken cancellationToken = ...)`
  - `ValueTask<ValueTuple<McpTask, TResult>> WaitForTaskResultAsync<TResult>(string taskId, JsonSerializerOptions jsonSerializerOptions = ..., CancellationToken cancellationToken = ...)`
  - `ClientCapabilities ClientCapabilities { get; }`
  - `Implementation ClientInfo { get; }`
  - `Nullable<LoggingLevel> LoggingLevel { get; }`
  - `McpServerOptions ServerOptions { get; }`
  - `IServiceProvider Services { get; }`

`class McpServerFilters`
  - `McpServerFilters()`
  - `McpMessageFilters Message { get; set; }`
  - `McpRequestFilters Request { get; set; }`

`class McpServerHandlers`
  - `McpServerHandlers()`
  - `McpRequestHandler<CallToolRequestParams, CallToolResult> CallToolHandler { get; set; }`
  - `McpRequestHandler<CompleteRequestParams, CompleteResult> CompleteHandler { get; set; }`
  - `McpRequestHandler<GetPromptRequestParams, GetPromptResult> GetPromptHandler { get; set; }`
  - `McpRequestHandler<ListPromptsRequestParams, ListPromptsResult> ListPromptsHandler { get; set; }`
  - `McpRequestHandler<ListResourceTemplatesRequestParams, ListResourceTemplatesResult> ListResourceTemplatesHandler { get; set; }`
  - `McpRequestHandler<ListResourcesRequestParams, ListResourcesResult> ListResourcesHandler { get; set; }`
  - `McpRequestHandler<ListToolsRequestParams, ListToolsResult> ListToolsHandler { get; set; }`
  - `IEnumerable<KeyValuePair<string, Func<JsonRpcNotification, CancellationToken, ValueTask>>> NotificationHandlers { get; set; }`
  - `McpRequestHandler<ReadResourceRequestParams, ReadResourceResult> ReadResourceHandler { get; set; }`
  - `McpRequestHandler<SetLevelRequestParams, EmptyResult> SetLoggingLevelHandler { get; set; }`
  - `McpRequestHandler<SubscribeRequestParams, EmptyResult> SubscribeToResourcesHandler { get; set; }`
  - `McpRequestHandler<UnsubscribeRequestParams, EmptyResult> UnsubscribeFromResourcesHandler { get; set; }`

`class McpServerOptions`
  - `McpServerOptions()`
  - `ServerCapabilities Capabilities { get; set; }`
  - `McpServerFilters Filters { get; set; }`
  - `McpServerHandlers Handlers { get; set; }`
  - `TimeSpan InitializationTimeout { get; set; }`
  - `ClientCapabilities KnownClientCapabilities { get; set; }`
  - `Implementation KnownClientInfo { get; set; }`
  - `int MaxSamplingOutputTokens { get; set; }`
  - `McpServerPrimitiveCollection<McpServerPrompt> PromptCollection { get; set; }`
  - `string ProtocolVersion { get; set; }`
  - `McpServerResourceCollection ResourceCollection { get; set; }`
  - `bool ScopeRequests { get; set; }`
  - `bool SendTaskStatusNotifications { get; set; }`
  - `Implementation ServerInfo { get; set; }`
  - `string ServerInstructions { get; set; }`
  - `IMcpTaskStore TaskStore { get; set; }`
  - `McpServerPrimitiveCollection<McpServerTool> ToolCollection { get; set; }`

`class McpServerPrimitiveCollection<T>`
  - `McpServerPrimitiveCollection`1(IEqualityComparer<string> keyComparer = ...)`
  - `void Add(T primitive)`
  - `void Clear()`
  - `bool Contains(T primitive)`
  - `void CopyTo(T[] array, int arrayIndex)`
  - `IEnumerator<T> GetEnumerator()`
  - `bool Remove(T primitive)`
  - `T[] ToArray()`
  - `bool TryAdd(T primitive)`
  - `bool TryGetPrimitive(string name, out T primitive)`
  - `int Count { get; }`
  - `bool IsEmpty { get; }`
  - `T Item { get; }`
  - `ICollection<string> PrimitiveNames { get; }`

`class McpServerPrompt`
  - `McpServerPrompt Create(Delegate method, McpServerPromptCreateOptions options = ...)`
  - `McpServerPrompt Create(MethodInfo method, object target = ..., McpServerPromptCreateOptions options = ...)`
  - `McpServerPrompt Create(MethodInfo method, Func<RequestContext<GetPromptRequestParams>, object> createTargetFunc, McpServerPromptCreateOptions options = ...)`
  - `ValueTask<GetPromptResult> GetAsync(RequestContext<GetPromptRequestParams> request, CancellationToken cancellationToken = ...)`
  - `string ToString()`
  - `IReadOnlyList<object> Metadata { get; }`
  - `Prompt ProtocolPrompt { get; }`

`class McpServerPromptAttribute`
  - `McpServerPromptAttribute()`
  - `string IconSource { get; set; }`
  - `string Name { get; set; }`
  - `string Title { get; set; }`

`class McpServerPromptCreateOptions`
  - `McpServerPromptCreateOptions()`
  - `string Description { get; set; }`
  - `IList<Icon> Icons { get; set; }`
  - `JsonObject Meta { get; set; }`
  - `IReadOnlyList<object> Metadata { get; set; }`
  - `string Name { get; set; }`
  - `JsonSerializerOptions SerializerOptions { get; set; }`
  - `IServiceProvider Services { get; set; }`
  - `string Title { get; set; }`

`class McpServerPromptTypeAttribute`
  - `McpServerPromptTypeAttribute()`

`class McpServerResource`
  - `McpServerResource Create(Delegate method, McpServerResourceCreateOptions options = ...)`
  - `McpServerResource Create(MethodInfo method, object target = ..., McpServerResourceCreateOptions options = ...)`
  - `McpServerResource Create(MethodInfo method, Func<RequestContext<ReadResourceRequestParams>, object> createTargetFunc, McpServerResourceCreateOptions options = ...)`
  - `bool IsMatch(string uri)`
  - `ValueTask<ReadResourceResult> ReadAsync(RequestContext<ReadResourceRequestParams> request, CancellationToken cancellationToken = ...)`
  - `string ToString()`
  - `bool IsTemplated { get; }`
  - `IReadOnlyList<object> Metadata { get; }`
  - `Resource ProtocolResource { get; }`
  - `ResourceTemplate ProtocolResourceTemplate { get; }`

`class McpServerResourceAttribute`
  - `McpServerResourceAttribute()`
  - `string IconSource { get; set; }`
  - `string MimeType { get; set; }`
  - `string Name { get; set; }`
  - `string Title { get; set; }`
  - `string UriTemplate { get; set; }`

`class McpServerResourceCollection`
  - `McpServerResourceCollection()`

`class McpServerResourceCreateOptions`
  - `McpServerResourceCreateOptions()`
  - `string Description { get; set; }`
  - `IList<Icon> Icons { get; set; }`
  - `JsonObject Meta { get; set; }`
  - `IReadOnlyList<object> Metadata { get; set; }`
  - `string MimeType { get; set; }`
  - `string Name { get; set; }`
  - `JsonSerializerOptions SerializerOptions { get; set; }`
  - `IServiceProvider Services { get; set; }`
  - `string Title { get; set; }`
  - `string UriTemplate { get; set; }`

`class McpServerResourceTypeAttribute`
  - `McpServerResourceTypeAttribute()`

`class McpServerTool`
  - `McpServerTool Create(Delegate method, McpServerToolCreateOptions options = ...)`
  - `McpServerTool Create(MethodInfo method, object target = ..., McpServerToolCreateOptions options = ...)`
  - `McpServerTool Create(MethodInfo method, Func<RequestContext<CallToolRequestParams>, object> createTargetFunc, McpServerToolCreateOptions options = ...)`
  - `ValueTask<CallToolResult> InvokeAsync(RequestContext<CallToolRequestParams> request, CancellationToken cancellationToken = ...)`
  - `string ToString()`
  - `IReadOnlyList<object> Metadata { get; }`
  - `Tool ProtocolTool { get; }`

`class McpServerToolAttribute`
  - `McpServerToolAttribute()`
  - `bool Destructive { get; set; }`
  - `string IconSource { get; set; }`
  - `bool Idempotent { get; set; }`
  - `string Name { get; set; }`
  - `bool OpenWorld { get; set; }`
  - `Type OutputSchemaType { get; set; }`
  - `bool ReadOnly { get; set; }`
  - `ToolTaskSupport TaskSupport { get; set; }`
  - `string Title { get; set; }`
  - `bool UseStructuredContent { get; set; }`

`class McpServerToolCreateOptions`
  - `McpServerToolCreateOptions()`
  - `string Description { get; set; }`
  - `Nullable<bool> Destructive { get; set; }`
  - `ToolExecution Execution { get; set; }`
  - `IList<Icon> Icons { get; set; }`
  - `Nullable<bool> Idempotent { get; set; }`
  - `JsonObject Meta { get; set; }`
  - `IReadOnlyList<object> Metadata { get; set; }`
  - `string Name { get; set; }`
  - `Nullable<bool> OpenWorld { get; set; }`
  - `Nullable<JsonElement> OutputSchema { get; set; }`
  - `Nullable<bool> ReadOnly { get; set; }`
  - `JsonSerializerOptions SerializerOptions { get; set; }`
  - `IServiceProvider Services { get; set; }`
  - `string Title { get; set; }`
  - `bool UseStructuredContent { get; set; }`

`class McpServerToolTypeAttribute`
  - `McpServerToolTypeAttribute()`

`class MessageContext`
  - `MessageContext(McpServer server, JsonRpcMessage jsonRpcMessage)`
  - `IDictionary<string, object> Items { get; set; }`
  - `JsonRpcMessage JsonRpcMessage { get; set; }`
  - `McpServer Server { get; set; }`
  - `IServiceProvider Services { get; set; }`
  - `ClaimsPrincipal User { get; set; }`

`class RequestContext<TParams>`
  - `RequestContext`1(McpServer server, JsonRpcRequest jsonRpcRequest, TParams parameters)`
  - `RequestContext`1(McpServer server, JsonRpcRequest jsonRpcRequest)`
  - `ValueTask EnablePollingAsync(TimeSpan retryInterval, CancellationToken cancellationToken = ...)`
  - `JsonRpcRequest JsonRpcRequest { get; set; }`
  - `IMcpServerPrimitive MatchedPrimitive { get; set; }`
  - `TParams Params { get; set; }`

`enum SseEventStreamMode`
  - `values: Streaming, Polling`

`class SseEventStreamOptions`
  - `SseEventStreamOptions()`
  - `SseEventStreamMode Mode { get; set; }`
  - `string SessionId { get; set; }`
  - `string StreamId { get; set; }`

`class SseResponseStreamTransport`
  - `SseResponseStreamTransport(Stream sseResponseStream, string messageEndpoint = ..., string sessionId = ...)`
  - `ValueTask DisposeAsync()`
  - `Task OnMessageReceivedAsync(JsonRpcMessage message, CancellationToken cancellationToken = ...)`
  - `Task RunAsync(CancellationToken cancellationToken = ...)`
  - `Task SendMessageAsync(JsonRpcMessage message, CancellationToken cancellationToken = ...)`
  - `ChannelReader<JsonRpcMessage> MessageReader { get; }`
  - `string SessionId { get; }`

`class StdioServerTransport`
  - `StdioServerTransport(McpServerOptions serverOptions, ILoggerFactory loggerFactory = ...)`
  - `StdioServerTransport(string serverName, ILoggerFactory loggerFactory = ...)`

`class StreamServerTransport`
  - `StreamServerTransport(Stream inputStream, Stream outputStream, string serverName = ..., ILoggerFactory loggerFactory = ...)`
  - `ValueTask DisposeAsync()`
  - `Task SendMessageAsync(JsonRpcMessage message, CancellationToken cancellationToken = ...)`

`class StreamableHttpServerTransport`
  - `StreamableHttpServerTransport(ILoggerFactory loggerFactory = ...)`
  - `ValueTask DisposeAsync()`
  - `Task HandleGetRequestAsync(Stream sseResponseStream, CancellationToken cancellationToken = ...)`
  - `ValueTask HandleInitializeRequestAsync(InitializeRequestParams initParams)`
  - `Task<bool> HandlePostRequestAsync(JsonRpcMessage message, Stream responseStream, CancellationToken cancellationToken = ...)`
  - `Task SendMessageAsync(JsonRpcMessage message, CancellationToken cancellationToken = ...)`
  - `ISseEventStreamStore EventStreamStore { get; set; }`
  - `bool FlowExecutionContextFromRequests { get; set; }`
  - `ChannelReader<JsonRpcMessage> MessageReader { get; }`
  - `Func<InitializeRequestParams, CancellationToken, ValueTask> OnSessionInitialized { get; set; }`
  - `string SessionId { get; set; }`
  - `bool Stateless { get; set; }`

`class UrlElicitationRequiredException`
  - `UrlElicitationRequiredException(string message, IEnumerable<ElicitRequestParams> elicitations)`
  - `IReadOnlyList<ElicitRequestParams> Elicitations { get; }`

### SkiaSharp

`enum GRBackend`
  - `values: Metal, OpenGL, Vulkan, Dawn, Direct3D`

`class GRBackendRenderTarget`
  - `GRBackendRenderTarget(GRBackend backend, GRBackendRenderTargetDesc desc)`
  - `GRBackendRenderTarget(int width, int height, int sampleCount, int stencilBits, GRGlFramebufferInfo glInfo)`
  - `GRBackendRenderTarget(int width, int height, int sampleCount, GRVkImageInfo vkImageInfo)`
  - `GRGlFramebufferInfo GetGlFramebufferInfo()`
  - `bool GetGlFramebufferInfo(out GRGlFramebufferInfo glInfo)`
  - `GRBackend Backend { get; }`
  - `int Height { get; }`
  - `bool IsValid { get; }`
  - `SKRectI Rect { get; }`
  - `int SampleCount { get; }`
  - `SKSizeI Size { get; }`
  - `int StencilBits { get; }`
  - `int Width { get; }`

`struct GRBackendRenderTargetDesc`
  - `bool Equals(GRBackendRenderTargetDesc obj)`
  - `bool Equals(object obj)`
  - `int GetHashCode()`
  - `GRPixelConfig Config { get; set; }`
  - `int Height { get; set; }`
  - `GRSurfaceOrigin Origin { get; set; }`
  - `SKRectI Rect { get; }`
  - `IntPtr RenderTargetHandle { get; set; }`
  - `int SampleCount { get; set; }`
  - `SKSizeI Size { get; }`
  - `int StencilBits { get; set; }`
  - `int Width { get; set; }`

`enum GRBackendState`
  - `values: None, All`

`class GRBackendTexture`
  - `GRBackendTexture(GRGlBackendTextureDesc desc)`
  - `GRBackendTexture(GRBackendTextureDesc desc)`
  - `GRBackendTexture(int width, int height, bool mipmapped, GRGlTextureInfo glInfo)`
  - `GRBackendTexture(int width, int height, GRVkImageInfo vkInfo)`
  - `GRGlTextureInfo GetGlTextureInfo()`
  - `bool GetGlTextureInfo(out GRGlTextureInfo glInfo)`
  - `GRBackend Backend { get; }`
  - `bool HasMipMaps { get; }`
  - `int Height { get; }`
  - `bool IsValid { get; }`
  - `SKRectI Rect { get; }`
  - `SKSizeI Size { get; }`
  - `int Width { get; }`

`struct GRBackendTextureDesc`
  - `bool Equals(GRBackendTextureDesc obj)`
  - `bool Equals(object obj)`
  - `int GetHashCode()`
  - `GRPixelConfig Config { get; set; }`
  - `GRBackendTextureDescFlags Flags { get; set; }`
  - `int Height { get; set; }`
  - `GRSurfaceOrigin Origin { get; set; }`
  - `SKRectI Rect { get; }`
  - `int SampleCount { get; set; }`
  - `SKSizeI Size { get; }`
  - `IntPtr TextureHandle { get; set; }`
  - `int Width { get; set; }`

`enum GRBackendTextureDescFlags`
  - `values: None, RenderTarget`

`class GRContext`
  - `void AbandonContext(bool releaseResources = ...)`
  - `GRContext Create(GRBackend backend)`
  - `GRContext Create(GRBackend backend, GRGlInterface backendContext)`
  - `GRContext Create(GRBackend backend, IntPtr backendContext)`
  - `GRContext CreateGl()`
  - `GRContext CreateGl(GRGlInterface backendContext)`
  - `GRContext CreateGl(GRContextOptions options)`
  - `GRContext CreateGl(GRGlInterface backendContext, GRContextOptions options)`
  - `GRContext CreateVulkan(GRVkBackendContext backendContext)`
  - `GRContext CreateVulkan(GRVkBackendContext backendContext, GRContextOptions options)`
  - `void DumpMemoryStatistics(SKTraceMemoryDump dump)`
  - `void Flush()`
  - `void Flush(bool submit, bool synchronous = ...)`
  - `int GetMaxSurfaceSampleCount(SKColorType colorType)`
  - `int GetRecommendedSampleCount(GRPixelConfig config, float dpi)`
  - `long GetResourceCacheLimit()`
  - `void GetResourceCacheLimits(out int maxResources, out long maxResourceBytes)`
  - `void GetResourceCacheUsage(out int maxResources, out long maxResourceBytes)`
  - `void PurgeResources()`
  - `void PurgeUnlockedResources(bool scratchResourcesOnly)`
  - `void PurgeUnlockedResources(long bytesToPurge, bool preferScratchResources)`
  - `void PurgeUnusedResources(long milliseconds)`
  - `void ResetContext(GRGlBackendState state)`
  - `void ResetContext(GRBackendState state = ...)`
  - `void ResetContext(UInt32 state)`
  - `void SetResourceCacheLimit(long maxResourceBytes)`
  - `void SetResourceCacheLimits(int maxResources, long maxResourceBytes)`
  - `void Submit(bool synchronous = ...)`
  - `GRBackend Backend { get; }`
  - `bool IsAbandoned { get; }`

`class GRContextOptions`
  - `GRContextOptions()`
  - `bool AllowPathMaskCaching { get; set; }`
  - `bool AvoidStencilBuffers { get; set; }`
  - `int BufferMapThreshold { get; set; }`
  - `bool DoManualMipmapping { get; set; }`
  - `int GlyphCacheTextureMaximumBytes { get; set; }`
  - `int RuntimeProgramCacheSize { get; set; }`

`enum GRGlBackendState`
  - `values: None, RenderTarget, TextureBinding, View, Blend, MSAAEnable, Vertex, Stencil, PixelStore, Program, FixedFunction, Misc, PathRendering, All`

`struct GRGlBackendTextureDesc`
  - `bool Equals(GRGlBackendTextureDesc obj)`
  - `bool Equals(object obj)`
  - `int GetHashCode()`
  - `GRPixelConfig Config { get; set; }`
  - `GRBackendTextureDescFlags Flags { get; set; }`
  - `int Height { get; set; }`
  - `GRSurfaceOrigin Origin { get; set; }`
  - `SKRectI Rect { get; }`
  - `int SampleCount { get; set; }`
  - `SKSizeI Size { get; }`
  - `GRGlTextureInfo TextureHandle { get; set; }`
  - `int Width { get; set; }`

`struct GRGlFramebufferInfo`
  - `GRGlFramebufferInfo(UInt32 fboId)`
  - `GRGlFramebufferInfo(UInt32 fboId, UInt32 format)`
  - `bool Equals(GRGlFramebufferInfo obj)`
  - `bool Equals(object obj)`
  - `int GetHashCode()`
  - `UInt32 Format { get; set; }`
  - `UInt32 FramebufferObjectId { get; set; }`

`class GRGlGetProcDelegate`
  - `GRGlGetProcDelegate(object object, IntPtr method)`
  - `IAsyncResult BeginInvoke(object context, string name, AsyncCallback callback, object object)`
  - `IntPtr EndInvoke(IAsyncResult result)`
  - `IntPtr Invoke(object context, string name)`

`class GRGlGetProcedureAddressDelegate`
  - `GRGlGetProcedureAddressDelegate(object object, IntPtr method)`
  - `IAsyncResult BeginInvoke(string name, AsyncCallback callback, object object)`
  - `IntPtr EndInvoke(IAsyncResult result)`
  - `IntPtr Invoke(string name)`

`class GRGlInterface`
  - `GRGlInterface AssembleAngleInterface(GRGlGetProcDelegate get)`
  - `GRGlInterface AssembleAngleInterface(object context, GRGlGetProcDelegate get)`
  - `GRGlInterface AssembleGlInterface(GRGlGetProcDelegate get)`
  - `GRGlInterface AssembleGlInterface(object context, GRGlGetProcDelegate get)`
  - `GRGlInterface AssembleGlesInterface(GRGlGetProcDelegate get)`
  - `GRGlInterface AssembleGlesInterface(object context, GRGlGetProcDelegate get)`
  - `GRGlInterface AssembleInterface(GRGlGetProcDelegate get)`
  - `GRGlInterface AssembleInterface(object context, GRGlGetProcDelegate get)`
  - `GRGlInterface Create()`
  - `GRGlInterface Create(GRGlGetProcedureAddressDelegate get)`
  - `GRGlInterface CreateAngle()`
  - `GRGlInterface CreateAngle(GRGlGetProcedureAddressDelegate get)`
  - `GRGlInterface CreateDefaultInterface()`
  - `GRGlInterface CreateEvas(IntPtr evas)`
  - `GRGlInterface CreateGles(GRGlGetProcedureAddressDelegate get)`
  - `GRGlInterface CreateNativeAngleInterface()`
  - `GRGlInterface CreateNativeEvasInterface(IntPtr evas)`
  - `GRGlInterface CreateNativeGlInterface()`
  - `GRGlInterface CreateOpenGl(GRGlGetProcedureAddressDelegate get)`
  - `GRGlInterface CreateWebGl(GRGlGetProcedureAddressDelegate get)`
  - `bool HasExtension(string extension)`
  - `bool Validate()`

`struct GRGlTextureInfo`
  - `GRGlTextureInfo(UInt32 target, UInt32 id)`
  - `GRGlTextureInfo(UInt32 target, UInt32 id, UInt32 format)`
  - `bool Equals(GRGlTextureInfo obj)`
  - `bool Equals(object obj)`
  - `int GetHashCode()`
  - `UInt32 Format { get; set; }`
  - `UInt32 Id { get; set; }`
  - `UInt32 Target { get; set; }`

`enum GRPixelConfig`
  - `values: Unknown, Alpha8, Gray8, Rgb565, Rgba4444, Rgba8888, Rgb888, Bgra8888, Srgba8888, Sbgra8888, Rgba1010102, RgbaFloat, RgFloat, AlphaHalf, RgbaHalf, Alpha8AsAlpha, Alpha8AsRed, AlphaHalfAsLum, AlphaHalfAsRed, Gray8AsLum, Gray8AsRed, RgbaHalfClamped, Alpha16, Rg1616, Rgba16161616, RgHalf, Rg88, Rgb888x, RgbEtc1`

`class GRRecordingContext`
  - `int GetMaxSurfaceSampleCount(SKColorType colorType)`
  - `GRBackend Backend { get; }`

`enum GRSurfaceOrigin`
  - `values: TopLeft, BottomLeft`

`struct GRVkAlloc`
  - `bool Equals(GRVkAlloc obj)`
  - `bool Equals(object obj)`
  - `int GetHashCode()`
  - `IntPtr BackendMemory { get; set; }`
  - `UInt32 Flags { get; set; }`
  - `UInt64 Memory { get; set; }`
  - `UInt64 Offset { get; set; }`
  - `UInt64 Size { get; set; }`

`class GRVkBackendContext`
  - `GRVkBackendContext()`
  - `void Dispose()`
  - `GRVkExtensions Extensions { get; set; }`
  - `GRVkGetProcedureAddressDelegate GetProcedureAddress { get; set; }`
  - `UInt32 GraphicsQueueIndex { get; set; }`
  - `UInt32 MaxAPIVersion { get; set; }`
  - `bool ProtectedContext { get; set; }`
  - `IntPtr VkDevice { get; set; }`
  - `IntPtr VkInstance { get; set; }`
  - `IntPtr VkPhysicalDevice { get; set; }`
  - `IntPtr VkPhysicalDeviceFeatures { get; set; }`
  - `IntPtr VkPhysicalDeviceFeatures2 { get; set; }`
  - `IntPtr VkQueue { get; set; }`

`class GRVkExtensions`
  - `GRVkExtensions Create(GRVkGetProcedureAddressDelegate getProc, IntPtr vkInstance, IntPtr vkPhysicalDevice, string[] instanceExtensions, string[] deviceExtensions)`
  - `void HasExtension(string extension, int minVersion)`
  - `void Initialize(GRVkGetProcedureAddressDelegate getProc, IntPtr vkInstance, IntPtr vkPhysicalDevice)`
  - `void Initialize(GRVkGetProcedureAddressDelegate getProc, IntPtr vkInstance, IntPtr vkPhysicalDevice, string[] instanceExtensions, string[] deviceExtensions)`

`class GRVkGetProcedureAddressDelegate`
  - `GRVkGetProcedureAddressDelegate(object object, IntPtr method)`
  - `IAsyncResult BeginInvoke(string name, IntPtr instance, IntPtr device, AsyncCallback callback, object object)`
  - `IntPtr EndInvoke(IAsyncResult result)`
  - `IntPtr Invoke(string name, IntPtr instance, IntPtr device)`

`struct GRVkImageInfo`
  - `bool Equals(GRVkImageInfo obj)`
  - `bool Equals(object obj)`
  - `int GetHashCode()`
  - `GRVkAlloc Alloc { get; set; }`
  - `UInt32 CurrentQueueFamily { get; set; }`
  - `UInt32 Format { get; set; }`
  - `UInt64 Image { get; set; }`
  - `UInt32 ImageLayout { get; set; }`
  - `UInt32 ImageTiling { get; set; }`
  - `UInt32 ImageUsageFlags { get; set; }`
  - `UInt32 LevelCount { get; set; }`
  - `bool Protected { get; set; }`
  - `UInt32 SampleCount { get; set; }`
  - `UInt32 SharingMode { get; set; }`
  - `GrVkYcbcrConversionInfo YcbcrConversionInfo { get; set; }`

`struct GrVkYcbcrConversionInfo`
  - `bool Equals(GrVkYcbcrConversionInfo obj)`
  - `bool Equals(object obj)`
  - `int GetHashCode()`
  - `UInt32 ChromaFilter { get; set; }`
  - `UInt64 ExternalFormat { get; set; }`
  - `UInt32 ForceExplicitReconstruction { get; set; }`
  - `UInt32 Format { get; set; }`
  - `UInt32 FormatFeatures { get; set; }`
  - `UInt32 XChromaOffset { get; set; }`
  - `UInt32 YChromaOffset { get; set; }`
  - `UInt32 YcbcrModel { get; set; }`
  - `UInt32 YcbcrRange { get; set; }`

`interface IPlatformLock`
  - `void EnterReadLock()`
  - `void EnterUpgradeableReadLock()`
  - `void EnterWriteLock()`
  - `void ExitReadLock()`
  - `void ExitUpgradeableReadLock()`
  - `void ExitWriteLock()`

`class PlatformConfiguration`
  - `bool Is64Bit { get; }`
  - `bool IsArm { get; }`
  - `bool IsGlibc { get; }`
  - `bool IsLinux { get; }`
  - `bool IsMac { get; }`
  - `bool IsUnix { get; }`
  - `bool IsWindows { get; }`
  - `string LinuxFlavor { get; set; }`

`class PlatformLock`
  - `IPlatformLock Create()`
  - `IPlatformLock DefaultFactory()`
  - `Func<IPlatformLock> Factory { get; set; }`

`class SK3dView`
  - `SK3dView()`
  - `void ApplyToCanvas(SKCanvas canvas)`
  - `float DotWithNormal(float dx, float dy, float dz)`
  - `void GetMatrix(SKMatrix matrix)`
  - `void Restore()`
  - `void RotateXDegrees(float degrees)`
  - `void RotateXRadians(float radians)`
  - `void RotateYDegrees(float degrees)`
  - `void RotateYRadians(float radians)`
  - `void RotateZDegrees(float degrees)`
  - `void RotateZRadians(float radians)`
  - `void Save()`
  - `void Translate(float x, float y, float z)`
  - `void TranslateX(float x)`
  - `void TranslateY(float y)`
  - `void TranslateZ(float z)`
  - `SKMatrix Matrix { get; }`

`enum SKAlphaType`
  - `values: Unknown, Opaque, Premul, Unpremul`

`class SKAutoCanvasRestore`
  - `SKAutoCanvasRestore(SKCanvas canvas)`
  - `SKAutoCanvasRestore(SKCanvas canvas, bool doSave)`
  - `void Dispose()`
  - `void Restore()`

`class SKAutoCoInitialize`
  - `SKAutoCoInitialize()`
  - `void Dispose()`
  - `void Uninitialize()`
  - `bool Initialized { get; }`

`class SKAutoMaskFreeImage`
  - `SKAutoMaskFreeImage(IntPtr maskImage)`
  - `void Dispose()`

`class SKBitmap`
  - `SKBitmap()`
  - `SKBitmap(int width, int height, bool isOpaque = ...)`
  - `SKBitmap(int width, int height, SKColorType colorType, SKAlphaType alphaType)`
  - `SKBitmap(int width, int height, SKColorType colorType, SKAlphaType alphaType, SKColorSpace colorspace)`
  - `SKBitmap(SKImageInfo info)`
  - `SKBitmap(SKImageInfo info, int rowBytes)`
  - `SKBitmap(SKImageInfo info, SKColorTable ctable, SKBitmapAllocFlags flags)`
  - `SKBitmap(SKImageInfo info, SKBitmapAllocFlags flags)`
  - `SKBitmap(SKImageInfo info, SKColorTable ctable)`
  - `bool CanCopyTo(SKColorType colorType)`
  - `SKBitmap Copy()`
  - `SKBitmap Copy(SKColorType colorType)`
  - `bool CopyTo(SKBitmap destination)`
  - `bool CopyTo(SKBitmap destination, SKColorType colorType)`
  - `SKBitmap Decode(SKCodec codec)`
  - `SKBitmap Decode(SKCodec codec, SKImageInfo bitmapInfo)`
  - `SKBitmap Decode(Stream stream)`
  - `SKBitmap Decode(Stream stream, SKImageInfo bitmapInfo)`
  - `SKBitmap Decode(SKStream stream)`
  - `SKBitmap Decode(SKStream stream, SKImageInfo bitmapInfo)`
  - `SKBitmap Decode(SKData data)`
  - `SKBitmap Decode(SKData data, SKImageInfo bitmapInfo)`
  - `SKBitmap Decode(string filename)`
  - `SKBitmap Decode(string filename, SKImageInfo bitmapInfo)`
  - `SKBitmap Decode(byte[] buffer)`
  - `SKBitmap Decode(byte[] buffer, SKImageInfo bitmapInfo)`
  - `SKBitmap Decode(ReadOnlySpan<byte> buffer)`
  - `SKBitmap Decode(ReadOnlySpan<byte> buffer, SKImageInfo bitmapInfo)`
  - `SKImageInfo DecodeBounds(Stream stream)`
  - `SKImageInfo DecodeBounds(SKStream stream)`
  - `SKImageInfo DecodeBounds(SKData data)`
  - `SKImageInfo DecodeBounds(string filename)`
  - `SKImageInfo DecodeBounds(byte[] buffer)`
  - `SKImageInfo DecodeBounds(ReadOnlySpan<byte> buffer)`
  - `SKData Encode(SKEncodedImageFormat format, int quality)`
  - `bool Encode(Stream dst, SKEncodedImageFormat format, int quality)`
  - `bool Encode(SKWStream dst, SKEncodedImageFormat format, int quality)`
  - `void Erase(SKColor color)`
  - `void Erase(SKColor color, SKRectI rect)`
  - `bool ExtractAlpha(SKBitmap destination)`
  - `bool ExtractAlpha(SKBitmap destination, out SKPointI offset)`
  - `bool ExtractAlpha(SKBitmap destination, SKPaint paint)`
  - `bool ExtractAlpha(SKBitmap destination, SKPaint paint, out SKPointI offset)`
  - `bool ExtractSubset(SKBitmap destination, SKRectI subset)`
  - `SKBitmap FromImage(SKImage image)`
  - `IntPtr GetAddr(int x, int y)`
  - `UInt16 GetAddr16(int x, int y)`
  - `UInt32 GetAddr32(int x, int y)`
  - `byte GetAddr8(int x, int y)`
  - `IntPtr GetAddress(int x, int y)`
  - `SKPMColor GetIndex8Color(int x, int y)`
  - `SKColor GetPixel(int x, int y)`
  - `ReadOnlySpan<byte> GetPixelSpan()`
  - `IntPtr GetPixels()`
  - `IntPtr GetPixels(out IntPtr length)`
  - `bool InstallMaskPixels(SKMask mask)`
  - `bool InstallPixels(SKImageInfo info, IntPtr pixels)`
  - `bool InstallPixels(SKImageInfo info, IntPtr pixels, int rowBytes)`
  - `bool InstallPixels(SKImageInfo info, IntPtr pixels, int rowBytes, SKColorTable ctable)`
  - `bool InstallPixels(SKImageInfo info, IntPtr pixels, int rowBytes, SKColorTable ctable, SKBitmapReleaseDelegate releaseProc, object context)`
  - `... (properties omitted)`

`enum SKBitmapAllocFlags`
  - `values: None, ZeroPixels`

`class SKBitmapReleaseDelegate`
  - `SKBitmapReleaseDelegate(object object, IntPtr method)`
  - `IAsyncResult BeginInvoke(IntPtr address, object context, AsyncCallback callback, object object)`
  - `void EndInvoke(IAsyncResult result)`
  - `void Invoke(IntPtr address, object context)`

`enum SKBitmapResizeMethod`
  - `values: Box, Triangle, Lanczos3, Hamming, Mitchell`

`enum SKBlendMode`
  - `values: Clear, Src, Dst, SrcOver, DstOver, SrcIn, DstIn, SrcOut, DstOut, SrcATop, DstATop, Xor, Plus, Modulate, Screen, Overlay, Darken, Lighten, ColorDodge, ColorBurn, HardLight, SoftLight, Difference, Exclusion, Multiply, Hue, Saturation, Color, Luminosity`

`enum SKBlurMaskFilterFlags`
  - `values: None, IgnoreTransform, HighQuality, All`

`enum SKBlurStyle`
  - `values: Normal, Solid, Outer, Inner`

`class SKCanvas`
  - `SKCanvas(SKBitmap bitmap)`
  - `void Clear()`
  - `void Clear(SKColor color)`
  - `void Clear(SKColorF color)`
  - `void ClipPath(SKPath path, SKClipOperation operation = ..., bool antialias = ...)`
  - `void ClipRect(SKRect rect, SKClipOperation operation = ..., bool antialias = ...)`
  - `void ClipRegion(SKRegion region, SKClipOperation operation = ...)`
  - `void ClipRoundRect(SKRoundRect rect, SKClipOperation operation = ..., bool antialias = ...)`
  - `void Concat(SKMatrix m)`
  - `void Discard()`
  - `void DrawAnnotation(SKRect rect, string key, SKData value)`
  - `void DrawArc(SKRect oval, float startAngle, float sweepAngle, bool useCenter, SKPaint paint)`
  - `void DrawAtlas(SKImage atlas, SKRect[] sprites, SKRotationScaleMatrix[] transforms, SKPaint paint)`
  - `void DrawAtlas(SKImage atlas, SKRect[] sprites, SKRotationScaleMatrix[] transforms, SKColor[] colors, SKBlendMode mode, SKPaint paint)`
  - `void DrawAtlas(SKImage atlas, SKRect[] sprites, SKRotationScaleMatrix[] transforms, SKColor[] colors, SKBlendMode mode, SKRect cullRect, SKPaint paint)`
  - `void DrawBitmap(SKBitmap bitmap, SKPoint p, SKPaint paint = ...)`
  - `void DrawBitmap(SKBitmap bitmap, float x, float y, SKPaint paint = ...)`
  - `void DrawBitmap(SKBitmap bitmap, SKRect dest, SKPaint paint = ...)`
  - `void DrawBitmap(SKBitmap bitmap, SKRect source, SKRect dest, SKPaint paint = ...)`
  - `void DrawBitmapLattice(SKBitmap bitmap, int[] xDivs, int[] yDivs, SKRect dst, SKPaint paint = ...)`
  - `void DrawBitmapLattice(SKBitmap bitmap, SKLattice lattice, SKRect dst, SKPaint paint = ...)`
  - `void DrawBitmapNinePatch(SKBitmap bitmap, SKRectI center, SKRect dst, SKPaint paint = ...)`
  - `void DrawCircle(float cx, float cy, float radius, SKPaint paint)`
  - `void DrawCircle(SKPoint c, float radius, SKPaint paint)`
  - `void DrawColor(SKColor color, SKBlendMode mode = ...)`
  - `void DrawColor(SKColorF color, SKBlendMode mode = ...)`
  - `void DrawDrawable(SKDrawable drawable, SKMatrix matrix)`
  - `void DrawDrawable(SKDrawable drawable, float x, float y)`
  - `void DrawDrawable(SKDrawable drawable, SKPoint p)`
  - `void DrawImage(SKImage image, SKPoint p, SKPaint paint = ...)`
  - `void DrawImage(SKImage image, float x, float y, SKPaint paint = ...)`
  - `void DrawImage(SKImage image, SKRect dest, SKPaint paint = ...)`
  - `void DrawImage(SKImage image, SKRect source, SKRect dest, SKPaint paint = ...)`
  - `void DrawImageLattice(SKImage image, int[] xDivs, int[] yDivs, SKRect dst, SKPaint paint = ...)`
  - `void DrawImageLattice(SKImage image, SKLattice lattice, SKRect dst, SKPaint paint = ...)`
  - `void DrawImageNinePatch(SKImage image, SKRectI center, SKRect dst, SKPaint paint = ...)`
  - `void DrawLine(SKPoint p0, SKPoint p1, SKPaint paint)`
  - `void DrawLine(float x0, float y0, float x1, float y1, SKPaint paint)`
  - `void DrawLinkDestinationAnnotation(SKRect rect, SKData value)`
  - `SKData DrawLinkDestinationAnnotation(SKRect rect, string value)`
  - `void DrawNamedDestinationAnnotation(SKPoint point, SKData value)`
  - `SKData DrawNamedDestinationAnnotation(SKPoint point, string value)`
  - `void DrawOval(float cx, float cy, float rx, float ry, SKPaint paint)`
  - `void DrawOval(SKPoint c, SKSize r, SKPaint paint)`
  - `void DrawOval(SKRect rect, SKPaint paint)`
  - `void DrawPaint(SKPaint paint)`
  - `void DrawPatch(SKPoint[] cubics, SKColor[] colors, SKPoint[] texCoords, SKPaint paint)`
  - `void DrawPatch(SKPoint[] cubics, SKColor[] colors, SKPoint[] texCoords, SKBlendMode mode, SKPaint paint)`
  - `void DrawPath(SKPath path, SKPaint paint)`
  - `void DrawPicture(SKPicture picture, float x, float y, SKPaint paint = ...)`
  - `void DrawPicture(SKPicture picture, SKPoint p, SKPaint paint = ...)`
  - `void DrawPicture(SKPicture picture, SKMatrix matrix, SKPaint paint = ...)`
  - `void DrawPicture(SKPicture picture, SKPaint paint = ...)`
  - `void DrawPoint(SKPoint p, SKPaint paint)`
  - `void DrawPoint(float x, float y, SKPaint paint)`
  - `void DrawPoint(SKPoint p, SKColor color)`
  - `void DrawPoint(float x, float y, SKColor color)`
  - `void DrawPoints(SKPointMode mode, SKPoint[] points, SKPaint paint)`
  - `void DrawPositionedText(string text, SKPoint[] points, SKPaint paint)`
  - `void DrawPositionedText(byte[] text, SKPoint[] points, SKPaint paint)`
  - `... (properties omitted)`

`enum SKClipOperation`
  - `values: Difference, Intersect`

`class SKCodec`
  - `SKCodec Create(string filename)`
  - `SKCodec Create(string filename, out SKCodecResult result)`
  - `SKCodec Create(Stream stream)`
  - `SKCodec Create(Stream stream, out SKCodecResult result)`
  - `SKCodec Create(SKStream stream)`
  - `SKCodec Create(SKStream stream, out SKCodecResult result)`
  - `SKCodec Create(SKData data)`
  - `bool GetFrameInfo(int index, out SKCodecFrameInfo frameInfo)`
  - `int GetOutputScanline(int inputScanline)`
  - `SKCodecResult GetPixels(out byte[] pixels)`
  - `SKCodecResult GetPixels(SKImageInfo info, out byte[] pixels)`
  - `SKCodecResult GetPixels(SKImageInfo info, byte[] pixels)`
  - `SKCodecResult GetPixels(SKImageInfo info, IntPtr pixels)`
  - `SKCodecResult GetPixels(SKImageInfo info, IntPtr pixels, SKCodecOptions options)`
  - `SKCodecResult GetPixels(SKImageInfo info, IntPtr pixels, int rowBytes, SKCodecOptions options)`
  - `SKCodecResult GetPixels(SKImageInfo info, IntPtr pixels, int rowBytes, SKCodecOptions options, IntPtr colorTable, int colorTableCount)`
  - `SKCodecResult GetPixels(SKImageInfo info, IntPtr pixels, SKCodecOptions options, IntPtr colorTable, int colorTableCount)`
  - `SKCodecResult GetPixels(SKImageInfo info, IntPtr pixels, IntPtr colorTable, int colorTableCount)`
  - `SKCodecResult GetPixels(SKImageInfo info, IntPtr pixels, int rowBytes, SKCodecOptions options, SKColorTable colorTable, int colorTableCount)`
  - `SKCodecResult GetPixels(SKImageInfo info, IntPtr pixels, SKCodecOptions options, SKColorTable colorTable, int colorTableCount)`
  - `SKCodecResult GetPixels(SKImageInfo info, IntPtr pixels, SKColorTable colorTable, int colorTableCount)`
  - `SKSizeI GetScaledDimensions(float desiredScale)`
  - `int GetScanlines(IntPtr dst, int countLines, int rowBytes)`
  - `bool GetValidSubset(SKRectI desiredSubset)`
  - `SKCodecResult IncrementalDecode(out int rowsDecoded)`
  - `SKCodecResult IncrementalDecode()`
  - `bool SkipScanlines(int countLines)`
  - `SKCodecResult StartIncrementalDecode(SKImageInfo info, IntPtr pixels, int rowBytes, SKCodecOptions options)`
  - `SKCodecResult StartIncrementalDecode(SKImageInfo info, IntPtr pixels, int rowBytes)`
  - `SKCodecResult StartIncrementalDecode(SKImageInfo info, IntPtr pixels, int rowBytes, SKCodecOptions options, IntPtr colorTable, int colorTableCount)`
  - `SKCodecResult StartIncrementalDecode(SKImageInfo info, IntPtr pixels, int rowBytes, SKCodecOptions options, SKColorTable colorTable, int colorTableCount)`
  - `SKCodecResult StartScanlineDecode(SKImageInfo info, SKCodecOptions options)`
  - `SKCodecResult StartScanlineDecode(SKImageInfo info)`
  - `SKCodecResult StartScanlineDecode(SKImageInfo info, SKCodecOptions options, IntPtr colorTable, int colorTableCount)`
  - `SKCodecResult StartScanlineDecode(SKImageInfo info, SKCodecOptions options, SKColorTable colorTable, int colorTableCount)`
  - `SKEncodedImageFormat EncodedFormat { get; }`
  - `SKEncodedOrigin EncodedOrigin { get; }`
  - `int FrameCount { get; }`
  - `SKCodecFrameInfo[] FrameInfo { get; }`
  - `SKImageInfo Info { get; }`
  - `int MinBufferedBytesNeeded { get; }`
  - `int NextScanline { get; }`
  - `SKCodecOrigin Origin { get; }`
  - `byte[] Pixels { get; }`
  - `int RepetitionCount { get; }`
  - `SKCodecScanlineOrder ScanlineOrder { get; }`

`enum SKCodecAnimationDisposalMethod`
  - `values: Keep, RestoreBackgroundColor, RestorePrevious`

`struct SKCodecFrameInfo`
  - `bool Equals(SKCodecFrameInfo obj)`
  - `bool Equals(object obj)`
  - `int GetHashCode()`
  - `SKAlphaType AlphaType { get; set; }`
  - `SKCodecAnimationDisposalMethod DisposalMethod { get; set; }`
  - `int Duration { get; set; }`
  - `bool FullyRecieved { get; set; }`
  - `int RequiredFrame { get; set; }`

`struct SKCodecOptions`
  - `SKCodecOptions(SKZeroInitialized zeroInitialized)`
  - `SKCodecOptions(SKZeroInitialized zeroInitialized, SKRectI subset)`
  - `SKCodecOptions(SKRectI subset)`
  - `SKCodecOptions(int frameIndex)`
  - `SKCodecOptions(int frameIndex, int priorFrame)`
  - `bool Equals(SKCodecOptions obj)`
  - `bool Equals(object obj)`
  - `int GetHashCode()`
  - `int FrameIndex { get; set; }`
  - `bool HasSubset { get; }`
  - `SKTransferFunctionBehavior PremulBehavior { get; set; }`
  - `int PriorFrame { get; set; }`
  - `Nullable<SKRectI> Subset { get; set; }`
  - `SKZeroInitialized ZeroInitialized { get; set; }`

`enum SKCodecOrigin`
  - `values: TopLeft, TopRight, BottomRight, BottomLeft, LeftTop, RightTop, RightBottom, LeftBottom`

`enum SKCodecResult`
  - `values: Success, IncompleteInput, ErrorInInput, InvalidConversion, InvalidScale, InvalidParameters, InvalidInput, CouldNotRewind, InternalError, Unimplemented`

`enum SKCodecScanlineOrder`
  - `values: TopDown, BottomUp`

`struct SKColor`
  - `SKColor(UInt32 value)`
  - `SKColor(byte red, byte green, byte blue, byte alpha)`
  - `SKColor(byte red, byte green, byte blue)`
  - `bool Equals(SKColor obj)`
  - `bool Equals(object other)`
  - `SKColor FromHsl(float h, float s, float l, byte a = ...)`
  - `SKColor FromHsv(float h, float s, float v, byte a = ...)`
  - `int GetHashCode()`
  - `SKColor Parse(string hexString)`
  - `void ToHsl(out float h, out float s, out float l)`
  - `void ToHsv(out float h, out float s, out float v)`
  - `string ToString()`
  - `bool TryParse(string hexString, out SKColor color)`
  - `SKColor WithAlpha(byte alpha)`
  - `SKColor WithBlue(byte blue)`
  - `SKColor WithGreen(byte green)`
  - `SKColor WithRed(byte red)`
  - `byte Alpha { get; }`
  - `byte Blue { get; }`
  - `byte Green { get; }`
  - `float Hue { get; }`
  - `byte Red { get; }`

`enum SKColorChannel`
  - `values: R, G, B, A`

`struct SKColorF`
  - `SKColorF(float red, float green, float blue)`
  - `SKColorF(float red, float green, float blue, float alpha)`
  - `SKColorF Clamp()`
  - `bool Equals(SKColorF obj)`
  - `bool Equals(object obj)`
  - `SKColorF FromHsl(float h, float s, float l, float a = ...)`
  - `SKColorF FromHsv(float h, float s, float v, float a = ...)`
  - `int GetHashCode()`
  - `void ToHsl(out float h, out float s, out float l)`
  - `void ToHsv(out float h, out float s, out float v)`
  - `string ToString()`
  - `SKColorF WithAlpha(float alpha)`
  - `SKColorF WithBlue(float blue)`
  - `SKColorF WithGreen(float green)`
  - `SKColorF WithRed(float red)`
  - `float Alpha { get; }`
  - `float Blue { get; }`
  - `float Green { get; }`
  - `float Hue { get; }`
  - `float Red { get; }`

`class SKColorFilter`
  - `SKColorFilter CreateBlendMode(SKColor c, SKBlendMode mode)`
  - `SKColorFilter CreateColorMatrix(float[] matrix)`
  - `SKColorFilter CreateCompose(SKColorFilter outer, SKColorFilter inner)`
  - `SKColorFilter CreateHighContrast(SKHighContrastConfig config)`
  - `SKColorFilter CreateHighContrast(bool grayscale, SKHighContrastConfigInvertStyle invertStyle, float contrast)`
  - `SKColorFilter CreateLighting(SKColor mul, SKColor add)`
  - `SKColorFilter CreateLumaColor()`
  - `SKColorFilter CreateTable(byte[] table)`
  - `SKColorFilter CreateTable(byte[] tableA, byte[] tableR, byte[] tableG, byte[] tableB)`

`class SKColorSpace`
  - `SKColorSpace CreateIcc(IntPtr input, long length)`
  - `SKColorSpace CreateIcc(byte[] input, long length)`
  - `SKColorSpace CreateIcc(byte[] input)`
  - `SKColorSpace CreateIcc(ReadOnlySpan<byte> input)`
  - `SKColorSpace CreateIcc(SKData input)`
  - `SKColorSpace CreateIcc(SKColorSpaceIccProfile profile)`
  - `SKColorSpace CreateRgb(SKColorSpaceRenderTargetGamma gamma, SKMatrix44 toXyzD50, SKColorSpaceFlags flags)`
  - `SKColorSpace CreateRgb(SKColorSpaceRenderTargetGamma gamma, SKColorSpaceGamut gamut, SKColorSpaceFlags flags)`
  - `SKColorSpace CreateRgb(SKColorSpaceTransferFn coeffs, SKMatrix44 toXyzD50, SKColorSpaceFlags flags)`
  - `SKColorSpace CreateRgb(SKColorSpaceTransferFn coeffs, SKColorSpaceGamut gamut, SKColorSpaceFlags flags)`
  - `SKColorSpace CreateRgb(SKColorSpaceRenderTargetGamma gamma, SKMatrix44 toXyzD50)`
  - `SKColorSpace CreateRgb(SKColorSpaceRenderTargetGamma gamma, SKColorSpaceGamut gamut)`
  - `SKColorSpace CreateRgb(SKColorSpaceTransferFn coeffs, SKMatrix44 toXyzD50)`
  - `SKColorSpace CreateRgb(SKColorSpaceTransferFn coeffs, SKColorSpaceGamut gamut)`
  - `SKColorSpace CreateRgb(SKNamedGamma gamma, SKMatrix44 toXyzD50)`
  - `SKColorSpace CreateRgb(SKNamedGamma gamma, SKColorSpaceGamut gamut)`
  - `SKColorSpace CreateRgb(SKColorSpaceTransferFn transferFn, SKColorSpaceXyz toXyzD50)`
  - `SKColorSpace CreateSrgb()`
  - `SKColorSpace CreateSrgbLinear()`
  - `bool Equal(SKColorSpace left, SKColorSpace right)`
  - `SKMatrix44 FromXyzD50()`
  - `SKColorSpaceTransferFn GetNumericalTransferFunction()`
  - `bool GetNumericalTransferFunction(out SKColorSpaceTransferFn fn)`
  - `bool ToColorSpaceXyz(out SKColorSpaceXyz toXyzD50)`
  - `SKColorSpaceXyz ToColorSpaceXyz()`
  - `SKColorSpace ToLinearGamma()`
  - `SKColorSpaceIccProfile ToProfile()`
  - `SKColorSpace ToSrgbGamma()`
  - `SKMatrix44 ToXyzD50()`
  - `bool ToXyzD50(SKMatrix44 toXyzD50)`
  - `bool GammaIsCloseToSrgb { get; }`
  - `bool GammaIsLinear { get; }`
  - `bool IsNumericalTransferFunction { get; }`
  - `bool IsSrgb { get; }`
  - `SKNamedGamma NamedGamma { get; }`
  - `SKColorSpaceType Type { get; }`

`enum SKColorSpaceFlags`
  - `values: None, NonLinearBlending`

`enum SKColorSpaceGamut`
  - `values: AdobeRgb, Dcip3D65, Rec2020, Srgb`

`class SKColorSpaceIccProfile`
  - `SKColorSpaceIccProfile()`
  - `SKColorSpaceIccProfile Create(byte[] data)`
  - `SKColorSpaceIccProfile Create(ReadOnlySpan<byte> data)`
  - `SKColorSpaceIccProfile Create(SKData data)`
  - `SKColorSpaceIccProfile Create(IntPtr data, long length)`
  - `bool ToColorSpaceXyz(out SKColorSpaceXyz toXyzD50)`
  - `SKColorSpaceXyz ToColorSpaceXyz()`
  - `IntPtr Buffer { get; }`
  - `long Size { get; }`

`struct SKColorSpacePrimaries`
  - `SKColorSpacePrimaries(float[] values)`
  - `SKColorSpacePrimaries(float rx, float ry, float gx, float gy, float bx, float by, float wx, float wy)`
  - `bool Equals(SKColorSpacePrimaries obj)`
  - `bool Equals(object obj)`
  - `int GetHashCode()`
  - `bool ToColorSpaceXyz(out SKColorSpaceXyz toXyzD50)`
  - `SKColorSpaceXyz ToColorSpaceXyz()`
  - `SKMatrix44 ToXyzD50()`
  - `bool ToXyzD50(SKMatrix44 toXyzD50)`
  - `float BX { get; set; }`
  - `float BY { get; set; }`
  - `float GX { get; set; }`
  - `float GY { get; set; }`
  - `float RX { get; set; }`
  - `float RY { get; set; }`
  - `float[] Values { get; }`
  - `float WX { get; set; }`
  - `float WY { get; set; }`

`enum SKColorSpaceRenderTargetGamma`
  - `values: Linear, Srgb`

`struct SKColorSpaceTransferFn`
  - `SKColorSpaceTransferFn(float[] values)`
  - `SKColorSpaceTransferFn(float g, float a, float b, float c, float d, float e, float f)`
  - `bool Equals(SKColorSpaceTransferFn obj)`
  - `bool Equals(object obj)`
  - `int GetHashCode()`
  - `SKColorSpaceTransferFn Invert()`
  - `float Transform(float x)`
  - `float A { get; set; }`
  - `float B { get; set; }`
  - `float C { get; set; }`
  - `float D { get; set; }`
  - `float E { get; set; }`
  - `float F { get; set; }`
  - `float G { get; set; }`
  - `SKColorSpaceTransferFn Hlg { get; }`
  - `SKColorSpaceTransferFn Linear { get; }`
  - `SKColorSpaceTransferFn Pq { get; }`
  - `SKColorSpaceTransferFn Rec2020 { get; }`
  - `SKColorSpaceTransferFn Srgb { get; }`
  - `SKColorSpaceTransferFn TwoDotTwo { get; }`
  - `float[] Values { get; }`

`enum SKColorSpaceType`
  - `values: Cmyk, Gray, Rgb`

`struct SKColorSpaceXyz`
  - `SKColorSpaceXyz(float value)`
  - `SKColorSpaceXyz(float[] values)`
  - `SKColorSpaceXyz(float m00, float m01, float m02, float m10, float m11, float m12, float m20, float m21, float m22)`
  - `SKColorSpaceXyz Concat(SKColorSpaceXyz a, SKColorSpaceXyz b)`
  - `bool Equals(SKColorSpaceXyz obj)`
  - `bool Equals(object obj)`
  - `int GetHashCode()`
  - `SKColorSpaceXyz Invert()`
  - `SKColorSpaceXyz AdobeRgb { get; }`
  - `SKColorSpaceXyz Dcip3 { get; }`
  - `SKColorSpaceXyz DisplayP3 { get; }`
  - `float Item { get; }`
  - `SKColorSpaceXyz Rec2020 { get; }`
  - `SKColorSpaceXyz Srgb { get; }`
  - `float[] Values { get; set; }`
  - `SKColorSpaceXyz Xyz { get; }`

`class SKColorTable`
  - `SKColorTable()`
  - `SKColorTable(int count)`
  - `SKColorTable(SKColor[] colors)`
  - `SKColorTable(SKColor[] colors, int count)`
  - `SKColorTable(SKPMColor[] colors)`
  - `SKColorTable(SKPMColor[] colors, int count)`
  - `SKColor GetUnPreMultipliedColor(int index)`
  - `IntPtr ReadColors()`
  - `SKPMColor[] Colors { get; }`
  - `int Count { get; }`
  - `SKPMColor Item { get; }`
  - `SKColor[] UnPreMultipledColors { get; }`

`enum SKColorType`
  - `values: Unknown, Alpha8, Rgb565, Argb4444, Rgba8888, Rgb888x, Bgra8888, Rgba1010102, Rgb101010x, Gray8, RgbaF16, RgbaF16Clamped, RgbaF32, Rg88, AlphaF16, RgF16, Alpha16, Rg1616, Rgba16161616, Bgra1010102, Bgr101010x`

`struct SKColors`
  - `SKColor Empty { get; }`

`enum SKCropRectFlags`
  - `values: HasNone, HasLeft, HasTop, HasWidth, HasHeight, HasAll`

`class SKData`
  - `ReadOnlySpan<byte> AsSpan()`
  - `Stream AsStream()`
  - `Stream AsStream(bool streamDisposesData)`
  - `SKData Create(int size)`
  - `SKData Create(long size)`
  - `SKData Create(UInt64 size)`
  - `SKData Create(string filename)`
  - `SKData Create(Stream stream)`
  - `SKData Create(Stream stream, int length)`
  - `SKData Create(Stream stream, UInt64 length)`
  - `SKData Create(Stream stream, long length)`
  - `SKData Create(SKStream stream)`
  - `SKData Create(SKStream stream, int length)`
  - `SKData Create(SKStream stream, UInt64 length)`
  - `SKData Create(SKStream stream, long length)`
  - `SKData Create(IntPtr address, int length)`
  - `SKData Create(IntPtr address, int length, SKDataReleaseDelegate releaseProc)`
  - `SKData Create(IntPtr address, int length, SKDataReleaseDelegate releaseProc, object context)`
  - `SKData CreateCopy(IntPtr bytes, int length)`
  - `SKData CreateCopy(IntPtr bytes, long length)`
  - `SKData CreateCopy(IntPtr bytes, UInt64 length)`
  - `SKData CreateCopy(byte[] bytes)`
  - `SKData CreateCopy(byte[] bytes, UInt64 length)`
  - `SKData CreateCopy(ReadOnlySpan<byte> bytes)`
  - `void SaveTo(Stream target)`
  - `SKData Subset(UInt64 offset, UInt64 length)`
  - `byte[] ToArray()`
  - `IntPtr Data { get; }`
  - `SKData Empty { get; }`
  - `bool IsEmpty { get; }`
  - `long Size { get; }`
  - `Span<byte> Span { get; }`

`class SKDataReleaseDelegate`
  - `SKDataReleaseDelegate(object object, IntPtr method)`
  - `IAsyncResult BeginInvoke(IntPtr address, object context, AsyncCallback callback, object object)`
  - `void EndInvoke(IAsyncResult result)`
  - `void Invoke(IntPtr address, object context)`

`enum SKDisplacementMapEffectChannelSelectorType`
  - `values: Unknown, R, G, B, A`

`class SKDocument`
  - `void Abort()`
  - `SKCanvas BeginPage(float width, float height)`
  - `SKCanvas BeginPage(float width, float height, SKRect content)`
  - `void Close()`
  - `SKDocument CreatePdf(SKWStream stream, SKDocumentPdfMetadata metadata, float dpi)`
  - `SKDocument CreatePdf(string path)`
  - `SKDocument CreatePdf(Stream stream)`
  - `SKDocument CreatePdf(SKWStream stream)`
  - `SKDocument CreatePdf(string path, float dpi)`
  - `SKDocument CreatePdf(Stream stream, float dpi)`
  - `SKDocument CreatePdf(SKWStream stream, float dpi)`
  - `SKDocument CreatePdf(string path, SKDocumentPdfMetadata metadata)`
  - `SKDocument CreatePdf(Stream stream, SKDocumentPdfMetadata metadata)`
  - `SKDocument CreatePdf(SKWStream stream, SKDocumentPdfMetadata metadata)`
  - `SKDocument CreateXps(string path)`
  - `SKDocument CreateXps(Stream stream)`
  - `SKDocument CreateXps(SKWStream stream)`
  - `SKDocument CreateXps(string path, float dpi)`
  - `SKDocument CreateXps(Stream stream, float dpi)`
  - `SKDocument CreateXps(SKWStream stream, float dpi)`
  - `void EndPage()`

`struct SKDocumentPdfMetadata`
  - `SKDocumentPdfMetadata(float rasterDpi)`
  - `SKDocumentPdfMetadata(int encodingQuality)`
  - `SKDocumentPdfMetadata(float rasterDpi, int encodingQuality)`
  - `bool Equals(SKDocumentPdfMetadata obj)`
  - `bool Equals(object obj)`
  - `int GetHashCode()`
  - `string Author { get; set; }`
  - `Nullable<DateTime> Creation { get; set; }`
  - `string Creator { get; set; }`
  - `int EncodingQuality { get; set; }`
  - `string Keywords { get; set; }`
  - `Nullable<DateTime> Modified { get; set; }`
  - `bool PdfA { get; set; }`
  - `string Producer { get; set; }`
  - `float RasterDpi { get; set; }`
  - `string Subject { get; set; }`
  - `string Title { get; set; }`

`class SKDrawable`
  - `void Draw(SKCanvas canvas, SKMatrix matrix)`
  - `void Draw(SKCanvas canvas, float x, float y)`
  - `void NotifyDrawingChanged()`
  - `SKPicture Snapshot()`
  - `SKRect Bounds { get; }`
  - `UInt32 GenerationId { get; }`

`enum SKDropShadowImageFilterShadowMode`
  - `values: DrawShadowAndForeground, DrawShadowOnly`

`class SKDynamicMemoryWStream`
  - `SKDynamicMemoryWStream()`
  - `void CopyTo(IntPtr data)`
  - `void CopyTo(Span<byte> data)`
  - `bool CopyTo(SKWStream dst)`
  - `bool CopyTo(Stream dst)`
  - `SKData CopyToData()`
  - `SKData DetachAsData()`
  - `SKStreamAsset DetachAsStream()`

`enum SKEncodedImageFormat`
  - `values: Bmp, Gif, Ico, Jpeg, Png, Wbmp, Webp, Pkm, Ktx, Astc, Dng, Heif, Avif`

`enum SKEncodedOrigin`
  - `values: TopLeft, TopRight, BottomRight, BottomLeft, LeftTop, RightTop, RightBottom, LeftBottom, Default`

`enum SKEncoding`
  - `values: Utf8, Utf16, Utf32`

`class SKFileStream`
  - `SKFileStream(string path)`
  - `bool IsPathSupported(string path)`
  - `SKStreamAsset OpenStream(string path)`
  - `bool IsValid { get; }`

`class SKFileWStream`
  - `SKFileWStream(string path)`
  - `bool IsPathSupported(string path)`
  - `SKWStream OpenStream(string path)`
  - `bool IsValid { get; }`

`enum SKFilterQuality`
  - `values: None, Low, Medium, High`

`class SKFont`
  - `SKFont()`
  - `SKFont(SKTypeface typeface, float size = ..., float scaleX = ..., float skewX = ...)`
  - `bool ContainsGlyph(int codepoint)`
  - `bool ContainsGlyphs(ReadOnlySpan<int> codepoints)`
  - `bool ContainsGlyphs(string text)`
  - `bool ContainsGlyphs(ReadOnlySpan<char> text)`
  - `bool ContainsGlyphs(ReadOnlySpan<byte> text, SKTextEncoding encoding)`
  - `bool ContainsGlyphs(IntPtr text, int length, SKTextEncoding encoding)`
  - `int CountGlyphs(string text)`
  - `int CountGlyphs(ReadOnlySpan<char> text)`
  - `int CountGlyphs(ReadOnlySpan<byte> text, SKTextEncoding encoding)`
  - `int CountGlyphs(IntPtr text, int length, SKTextEncoding encoding)`
  - `float GetFontMetrics(out SKFontMetrics metrics)`
  - `UInt16 GetGlyph(int codepoint)`
  - `void GetGlyphOffsets(ReadOnlySpan<UInt16> glyphs, Span<float> offsets, float origin = ...)`
  - `SKPath GetGlyphPath(UInt16 glyph)`
  - `void GetGlyphPaths(ReadOnlySpan<UInt16> glyphs, SKGlyphPathDelegate glyphPathDelegate)`
  - `void GetGlyphPositions(ReadOnlySpan<UInt16> glyphs, Span<SKPoint> positions, SKPoint origin = ...)`
  - `void GetGlyphWidths(ReadOnlySpan<UInt16> glyphs, Span<float> widths, Span<SKRect> bounds, SKPaint paint = ...)`
  - `void GetGlyphs(ReadOnlySpan<int> codepoints, Span<UInt16> glyphs)`
  - `void GetGlyphs(string text, Span<UInt16> glyphs)`
  - `void GetGlyphs(ReadOnlySpan<char> text, Span<UInt16> glyphs)`
  - `void GetGlyphs(ReadOnlySpan<byte> text, SKTextEncoding encoding, Span<UInt16> glyphs)`
  - `void GetGlyphs(IntPtr text, int length, SKTextEncoding encoding, Span<UInt16> glyphs)`
  - `float MeasureText(ReadOnlySpan<UInt16> glyphs, SKPaint paint = ...)`
  - `float MeasureText(ReadOnlySpan<UInt16> glyphs, out SKRect bounds, SKPaint paint = ...)`
  - `bool BaselineSnap { get; set; }`
  - `SKFontEdging Edging { get; set; }`
  - `bool EmbeddedBitmaps { get; set; }`
  - `bool Embolden { get; set; }`
  - `bool ForceAutoHinting { get; set; }`
  - `SKFontHinting Hinting { get; set; }`
  - `bool LinearMetrics { get; set; }`
  - `SKFontMetrics Metrics { get; }`
  - `float ScaleX { get; set; }`
  - `float Size { get; set; }`
  - `float SkewX { get; set; }`
  - `float Spacing { get; }`
  - `bool Subpixel { get; set; }`
  - `SKTypeface Typeface { get; set; }`

`enum SKFontEdging`
  - `values: Alias, Antialias, SubpixelAntialias`

`enum SKFontHinting`
  - `values: None, Slight, Normal, Full`

`class SKFontManager`
  - `SKFontManager CreateDefault()`
  - `SKTypeface CreateTypeface(string path, int index = ...)`
  - `SKTypeface CreateTypeface(Stream stream, int index = ...)`
  - `SKTypeface CreateTypeface(SKStreamAsset stream, int index = ...)`
  - `SKTypeface CreateTypeface(SKData data, int index = ...)`
  - `string GetFamilyName(int index)`
  - `string[] GetFontFamilies()`
  - `SKFontStyleSet GetFontStyles(int index)`
  - `SKFontStyleSet GetFontStyles(string familyName)`
  - `SKTypeface MatchCharacter(char character)`
  - `SKTypeface MatchCharacter(int character)`
  - `SKTypeface MatchCharacter(string familyName, char character)`
  - `SKTypeface MatchCharacter(string familyName, int character)`
  - `SKTypeface MatchCharacter(string familyName, string[] bcp47, char character)`
  - `SKTypeface MatchCharacter(string familyName, string[] bcp47, int character)`
  - `SKTypeface MatchCharacter(string familyName, SKFontStyleWeight weight, SKFontStyleWidth width, SKFontStyleSlant slant, string[] bcp47, char character)`
  - `SKTypeface MatchCharacter(string familyName, SKFontStyleWeight weight, SKFontStyleWidth width, SKFontStyleSlant slant, string[] bcp47, int character)`
  - `SKTypeface MatchCharacter(string familyName, int weight, int width, SKFontStyleSlant slant, string[] bcp47, int character)`
  - `SKTypeface MatchCharacter(string familyName, SKFontStyle style, string[] bcp47, int character)`
  - `SKTypeface MatchFamily(string familyName)`
  - `SKTypeface MatchFamily(string familyName, SKFontStyle style)`
  - `SKTypeface MatchTypeface(SKTypeface face, SKFontStyle style)`
  - `SKFontManager Default { get; }`
  - `IEnumerable<string> FontFamilies { get; }`
  - `int FontFamilyCount { get; }`

`struct SKFontMetrics`
  - `bool Equals(SKFontMetrics obj)`
  - `bool Equals(object obj)`
  - `int GetHashCode()`
  - `float Ascent { get; }`
  - `float AverageCharacterWidth { get; }`
  - `float Bottom { get; }`
  - `float CapHeight { get; }`
  - `float Descent { get; }`
  - `float Leading { get; }`
  - `float MaxCharacterWidth { get; }`
  - `Nullable<float> StrikeoutPosition { get; }`
  - `Nullable<float> StrikeoutThickness { get; }`
  - `float Top { get; }`
  - `Nullable<float> UnderlinePosition { get; }`
  - `Nullable<float> UnderlineThickness { get; }`
  - `float XHeight { get; }`
  - `float XMax { get; }`
  - `float XMin { get; }`

`class SKFontStyle`
  - `SKFontStyle()`
  - `SKFontStyle(SKFontStyleWeight weight, SKFontStyleWidth width, SKFontStyleSlant slant)`
  - `SKFontStyle(int weight, int width, SKFontStyleSlant slant)`
  - `SKFontStyle Bold { get; }`
  - `SKFontStyle BoldItalic { get; }`
  - `SKFontStyle Italic { get; }`
  - `SKFontStyle Normal { get; }`
  - `SKFontStyleSlant Slant { get; }`
  - `int Weight { get; }`
  - `int Width { get; }`

`class SKFontStyleSet`
  - `SKFontStyleSet()`
  - `SKTypeface CreateTypeface(int index)`
  - `SKTypeface CreateTypeface(SKFontStyle style)`
  - `IEnumerator<SKFontStyle> GetEnumerator()`
  - `string GetStyleName(int index)`
  - `int Count { get; }`
  - `SKFontStyle Item { get; }`

`enum SKFontStyleSlant`
  - `values: Upright, Italic, Oblique`

`enum SKFontStyleWeight`
  - `values: Invisible, Thin, ExtraLight, Light, Normal, Medium, SemiBold, Bold, ExtraBold, Black, ExtraBlack`

`enum SKFontStyleWidth`
  - `values: UltraCondensed, ExtraCondensed, Condensed, SemiCondensed, Normal, SemiExpanded, Expanded, ExtraExpanded, UltraExpanded`

`class SKFrontBufferedManagedStream`
  - `SKFrontBufferedManagedStream(Stream managedStream, int bufferSize)`
  - `SKFrontBufferedManagedStream(Stream managedStream, int bufferSize, bool disposeUnderlyingStream)`
  - `SKFrontBufferedManagedStream(SKStream nativeStream, int bufferSize)`
  - `SKFrontBufferedManagedStream(SKStream nativeStream, int bufferSize, bool disposeUnderlyingStream)`

`class SKFrontBufferedStream`
  - `SKFrontBufferedStream(Stream stream)`
  - `SKFrontBufferedStream(Stream stream, long bufferSize)`
  - `SKFrontBufferedStream(Stream stream, bool disposeUnderlyingStream)`
  - `SKFrontBufferedStream(Stream stream, long bufferSize, bool disposeUnderlyingStream)`
  - `void Flush()`
  - `int Read(byte[] buffer, int offset, int count)`
  - `long Seek(long offset, SeekOrigin origin)`
  - `void SetLength(long value)`
  - `void Write(byte[] buffer, int offset, int count)`
  - `bool CanRead { get; }`
  - `bool CanSeek { get; }`
  - `bool CanWrite { get; }`
  - `long Length { get; }`
  - `long Position { get; set; }`

`class SKGlyphPathDelegate`
  - `SKGlyphPathDelegate(object object, IntPtr method)`
  - `IAsyncResult BeginInvoke(SKPath path, SKMatrix matrix, AsyncCallback callback, object object)`
  - `void EndInvoke(IAsyncResult result)`
  - `void Invoke(SKPath path, SKMatrix matrix)`

`class SKGraphics`
  - `void DumpMemoryStatistics(SKTraceMemoryDump dump)`
  - `int GetFontCacheCountLimit()`
  - `int GetFontCacheCountUsed()`
  - `long GetFontCacheLimit()`
  - `int GetFontCachePointSizeLimit()`
  - `long GetFontCacheUsed()`
  - `long GetResourceCacheSingleAllocationByteLimit()`
  - `long GetResourceCacheTotalByteLimit()`
  - `long GetResourceCacheTotalBytesUsed()`
  - `void Init()`
  - `void PurgeAllCaches()`
  - `void PurgeFontCache()`
  - `void PurgeResourceCache()`
  - `int SetFontCacheCountLimit(int count)`
  - `long SetFontCacheLimit(long bytes)`
  - `int SetFontCachePointSizeLimit(int count)`
  - `long SetResourceCacheSingleAllocationByteLimit(long bytes)`
  - `long SetResourceCacheTotalByteLimit(long bytes)`

`struct SKHighContrastConfig`
  - `SKHighContrastConfig(bool grayscale, SKHighContrastConfigInvertStyle invertStyle, float contrast)`
  - `bool Equals(SKHighContrastConfig obj)`
  - `bool Equals(object obj)`
  - `int GetHashCode()`
  - `float Contrast { get; set; }`
  - `bool Grayscale { get; set; }`
  - `SKHighContrastConfigInvertStyle InvertStyle { get; set; }`
  - `bool IsValid { get; }`

`enum SKHighContrastConfigInvertStyle`
  - `values: NoInvert, InvertBrightness, InvertLightness`

`class SKHorizontalRunBuffer`
  - `Span<float> GetPositionSpan()`
  - `void SetPositions(ReadOnlySpan<float> positions)`

`class SKImage`
  - `SKImage ApplyImageFilter(SKImageFilter filter, SKRectI subset, SKRectI clipBounds, out SKRectI outSubset, out SKPoint outOffset)`
  - `SKImage ApplyImageFilter(SKImageFilter filter, SKRectI subset, SKRectI clipBounds, out SKRectI outSubset, out SKPointI outOffset)`
  - `SKImage ApplyImageFilter(GRContext context, SKImageFilter filter, SKRectI subset, SKRectI clipBounds, out SKRectI outSubset, out SKPointI outOffset)`
  - `SKImage ApplyImageFilter(GRRecordingContext context, SKImageFilter filter, SKRectI subset, SKRectI clipBounds, out SKRectI outSubset, out SKPointI outOffset)`
  - `SKImage Create(SKImageInfo info)`
  - `SKData Encode()`
  - `SKData Encode(SKPixelSerializer serializer)`
  - `SKData Encode(SKEncodedImageFormat format, int quality)`
  - `SKImage FromAdoptedTexture(GRContext context, GRBackendTextureDesc desc)`
  - `SKImage FromAdoptedTexture(GRContext context, GRBackendTextureDesc desc, SKAlphaType alpha)`
  - `SKImage FromAdoptedTexture(GRContext context, GRGlBackendTextureDesc desc)`
  - `SKImage FromAdoptedTexture(GRContext context, GRGlBackendTextureDesc desc, SKAlphaType alpha)`
  - `SKImage FromAdoptedTexture(GRContext context, GRBackendTexture texture, SKColorType colorType)`
  - `SKImage FromAdoptedTexture(GRContext context, GRBackendTexture texture, GRSurfaceOrigin origin, SKColorType colorType)`
  - `SKImage FromAdoptedTexture(GRContext context, GRBackendTexture texture, GRSurfaceOrigin origin, SKColorType colorType, SKAlphaType alpha)`
  - `SKImage FromAdoptedTexture(GRContext context, GRBackendTexture texture, GRSurfaceOrigin origin, SKColorType colorType, SKAlphaType alpha, SKColorSpace colorspace)`
  - `SKImage FromAdoptedTexture(GRRecordingContext context, GRBackendTexture texture, SKColorType colorType)`
  - `SKImage FromAdoptedTexture(GRRecordingContext context, GRBackendTexture texture, GRSurfaceOrigin origin, SKColorType colorType)`
  - `SKImage FromAdoptedTexture(GRRecordingContext context, GRBackendTexture texture, GRSurfaceOrigin origin, SKColorType colorType, SKAlphaType alpha)`
  - `SKImage FromAdoptedTexture(GRRecordingContext context, GRBackendTexture texture, GRSurfaceOrigin origin, SKColorType colorType, SKAlphaType alpha, SKColorSpace colorspace)`
  - `SKImage FromBitmap(SKBitmap bitmap)`
  - `SKImage FromEncodedData(SKData data, SKRectI subset)`
  - `SKImage FromEncodedData(SKData data)`
  - `SKImage FromEncodedData(ReadOnlySpan<byte> data)`
  - `SKImage FromEncodedData(byte[] data)`
  - `SKImage FromEncodedData(SKStream data)`
  - `SKImage FromEncodedData(Stream data)`
  - `SKImage FromEncodedData(string filename)`
  - `SKImage FromPicture(SKPicture picture, SKSizeI dimensions)`
  - `SKImage FromPicture(SKPicture picture, SKSizeI dimensions, SKMatrix matrix)`
  - `SKImage FromPicture(SKPicture picture, SKSizeI dimensions, SKPaint paint)`
  - `SKImage FromPicture(SKPicture picture, SKSizeI dimensions, SKMatrix matrix, SKPaint paint)`
  - `SKImage FromPixelCopy(SKImageInfo info, SKStream pixels)`
  - `SKImage FromPixelCopy(SKImageInfo info, SKStream pixels, int rowBytes)`
  - `SKImage FromPixelCopy(SKImageInfo info, Stream pixels)`
  - `SKImage FromPixelCopy(SKImageInfo info, Stream pixels, int rowBytes)`
  - `SKImage FromPixelCopy(SKImageInfo info, byte[] pixels)`
  - `SKImage FromPixelCopy(SKImageInfo info, byte[] pixels, int rowBytes)`
  - `SKImage FromPixelCopy(SKImageInfo info, IntPtr pixels)`
  - `SKImage FromPixelCopy(SKImageInfo info, IntPtr pixels, int rowBytes)`
  - `SKImage FromPixelCopy(SKImageInfo info, IntPtr pixels, int rowBytes, SKColorTable ctable)`
  - `SKImage FromPixelCopy(SKPixmap pixmap)`
  - `SKImage FromPixelCopy(SKImageInfo info, ReadOnlySpan<byte> pixels)`
  - `SKImage FromPixelCopy(SKImageInfo info, ReadOnlySpan<byte> pixels, int rowBytes)`
  - `SKImage FromPixelData(SKImageInfo info, SKData data, int rowBytes)`
  - `SKImage FromPixels(SKImageInfo info, SKData data)`
  - `SKImage FromPixels(SKImageInfo info, SKData data, int rowBytes)`
  - `SKImage FromPixels(SKImageInfo info, IntPtr pixels)`
  - `SKImage FromPixels(SKImageInfo info, IntPtr pixels, int rowBytes)`
  - `SKImage FromPixels(SKPixmap pixmap)`
  - `SKImage FromPixels(SKPixmap pixmap, SKImageRasterReleaseDelegate releaseProc)`
  - `SKImage FromPixels(SKPixmap pixmap, SKImageRasterReleaseDelegate releaseProc, object releaseContext)`
  - `SKImage FromTexture(GRContext context, GRBackendTextureDesc desc)`
  - `SKImage FromTexture(GRContext context, GRBackendTextureDesc desc, SKAlphaType alpha)`
  - `SKImage FromTexture(GRContext context, GRBackendTextureDesc desc, SKAlphaType alpha, SKImageTextureReleaseDelegate releaseProc)`
  - `SKImage FromTexture(GRContext context, GRBackendTextureDesc desc, SKAlphaType alpha, SKImageTextureReleaseDelegate releaseProc, object releaseContext)`
  - `SKImage FromTexture(GRContext context, GRGlBackendTextureDesc desc)`
  - `SKImage FromTexture(GRContext context, GRGlBackendTextureDesc desc, SKAlphaType alpha)`
  - `SKImage FromTexture(GRContext context, GRGlBackendTextureDesc desc, SKAlphaType alpha, SKImageTextureReleaseDelegate releaseProc)`
  - `SKImage FromTexture(GRContext context, GRGlBackendTextureDesc desc, SKAlphaType alpha, SKImageTextureReleaseDelegate releaseProc, object releaseContext)`
  - `... (properties omitted)`

`enum SKImageCachingHint`
  - `values: Allow, Disallow`

`class SKImageFilter`
  - `SKImageFilter CreateAlphaThreshold(SKRectI region, float innerThreshold, float outerThreshold, SKImageFilter input = ...)`
  - `SKImageFilter CreateAlphaThreshold(SKRegion region, float innerThreshold, float outerThreshold)`
  - `SKImageFilter CreateAlphaThreshold(SKRegion region, float innerThreshold, float outerThreshold, SKImageFilter input)`
  - `SKImageFilter CreateArithmetic(float k1, float k2, float k3, float k4, bool enforcePMColor, SKImageFilter background, SKImageFilter foreground)`
  - `SKImageFilter CreateArithmetic(float k1, float k2, float k3, float k4, bool enforcePMColor, SKImageFilter background, SKImageFilter foreground, SKRect cropRect)`
  - `SKImageFilter CreateArithmetic(float k1, float k2, float k3, float k4, bool enforcePMColor, SKImageFilter background, SKImageFilter foreground, CropRect cropRect)`
  - `SKImageFilter CreateBlendMode(SKBlendMode mode, SKImageFilter background)`
  - `SKImageFilter CreateBlendMode(SKBlendMode mode, SKImageFilter background, SKImageFilter foreground)`
  - `SKImageFilter CreateBlendMode(SKBlendMode mode, SKImageFilter background, SKImageFilter foreground, SKRect cropRect)`
  - `SKImageFilter CreateBlendMode(SKBlendMode mode, SKImageFilter background, SKImageFilter foreground, CropRect cropRect)`
  - `SKImageFilter CreateBlur(float sigmaX, float sigmaY)`
  - `SKImageFilter CreateBlur(float sigmaX, float sigmaY, SKImageFilter input)`
  - `SKImageFilter CreateBlur(float sigmaX, float sigmaY, SKImageFilter input, SKRect cropRect)`
  - `SKImageFilter CreateBlur(float sigmaX, float sigmaY, SKImageFilter input, CropRect cropRect)`
  - `SKImageFilter CreateBlur(float sigmaX, float sigmaY, SKShaderTileMode tileMode)`
  - `SKImageFilter CreateBlur(float sigmaX, float sigmaY, SKShaderTileMode tileMode, SKImageFilter input)`
  - `SKImageFilter CreateBlur(float sigmaX, float sigmaY, SKShaderTileMode tileMode, SKImageFilter input, SKRect cropRect)`
  - `SKImageFilter CreateBlur(float sigmaX, float sigmaY, SKShaderTileMode tileMode, SKImageFilter input, CropRect cropRect)`
  - `SKImageFilter CreateColorFilter(SKColorFilter cf)`
  - `SKImageFilter CreateColorFilter(SKColorFilter cf, SKImageFilter input)`
  - `SKImageFilter CreateColorFilter(SKColorFilter cf, SKImageFilter input, SKRect cropRect)`
  - `SKImageFilter CreateColorFilter(SKColorFilter cf, SKImageFilter input, CropRect cropRect)`
  - `SKImageFilter CreateCompose(SKImageFilter outer, SKImageFilter inner)`
  - `SKImageFilter CreateDilate(int radiusX, int radiusY, SKImageFilter input, CropRect cropRect)`
  - `SKImageFilter CreateDilate(float radiusX, float radiusY)`
  - `SKImageFilter CreateDilate(float radiusX, float radiusY, SKImageFilter input)`
  - `SKImageFilter CreateDilate(float radiusX, float radiusY, SKImageFilter input, SKRect cropRect)`
  - `SKImageFilter CreateDilate(float radiusX, float radiusY, SKImageFilter input, CropRect cropRect)`
  - `SKImageFilter CreateDisplacementMapEffect(SKDisplacementMapEffectChannelSelectorType xChannelSelector, SKDisplacementMapEffectChannelSelectorType yChannelSelector, float scale, SKImageFilter displacement, SKImageFilter input = ..., CropRect cropRect = ...)`
  - `SKImageFilter CreateDisplacementMapEffect(SKColorChannel xChannelSelector, SKColorChannel yChannelSelector, float scale, SKImageFilter displacement)`
  - `SKImageFilter CreateDisplacementMapEffect(SKColorChannel xChannelSelector, SKColorChannel yChannelSelector, float scale, SKImageFilter displacement, SKImageFilter input)`
  - `SKImageFilter CreateDisplacementMapEffect(SKColorChannel xChannelSelector, SKColorChannel yChannelSelector, float scale, SKImageFilter displacement, SKImageFilter input, SKRect cropRect)`
  - `SKImageFilter CreateDisplacementMapEffect(SKColorChannel xChannelSelector, SKColorChannel yChannelSelector, float scale, SKImageFilter displacement, SKImageFilter input, CropRect cropRect)`
  - `SKImageFilter CreateDistantLitDiffuse(SKPoint3 direction, SKColor lightColor, float surfaceScale, float kd)`
  - `SKImageFilter CreateDistantLitDiffuse(SKPoint3 direction, SKColor lightColor, float surfaceScale, float kd, SKImageFilter input)`
  - `SKImageFilter CreateDistantLitDiffuse(SKPoint3 direction, SKColor lightColor, float surfaceScale, float kd, SKImageFilter input, SKRect cropRect)`
  - `SKImageFilter CreateDistantLitDiffuse(SKPoint3 direction, SKColor lightColor, float surfaceScale, float kd, SKImageFilter input, CropRect cropRect)`
  - `SKImageFilter CreateDistantLitSpecular(SKPoint3 direction, SKColor lightColor, float surfaceScale, float ks, float shininess)`
  - `SKImageFilter CreateDistantLitSpecular(SKPoint3 direction, SKColor lightColor, float surfaceScale, float ks, float shininess, SKImageFilter input)`
  - `SKImageFilter CreateDistantLitSpecular(SKPoint3 direction, SKColor lightColor, float surfaceScale, float ks, float shininess, SKImageFilter input, SKRect cropRect)`
  - `SKImageFilter CreateDistantLitSpecular(SKPoint3 direction, SKColor lightColor, float surfaceScale, float ks, float shininess, SKImageFilter input, CropRect cropRect)`
  - `SKImageFilter CreateDropShadow(float dx, float dy, float sigmaX, float sigmaY, SKColor color, SKDropShadowImageFilterShadowMode shadowMode, SKImageFilter input = ..., CropRect cropRect = ...)`
  - `SKImageFilter CreateDropShadow(float dx, float dy, float sigmaX, float sigmaY, SKColor color)`
  - `SKImageFilter CreateDropShadow(float dx, float dy, float sigmaX, float sigmaY, SKColor color, SKImageFilter input)`
  - `SKImageFilter CreateDropShadow(float dx, float dy, float sigmaX, float sigmaY, SKColor color, SKImageFilter input, SKRect cropRect)`
  - `SKImageFilter CreateDropShadow(float dx, float dy, float sigmaX, float sigmaY, SKColor color, SKImageFilter input, CropRect cropRect)`
  - `SKImageFilter CreateDropShadowOnly(float dx, float dy, float sigmaX, float sigmaY, SKColor color)`
  - `SKImageFilter CreateDropShadowOnly(float dx, float dy, float sigmaX, float sigmaY, SKColor color, SKImageFilter input)`
  - `SKImageFilter CreateDropShadowOnly(float dx, float dy, float sigmaX, float sigmaY, SKColor color, SKImageFilter input, SKRect cropRect)`
  - `SKImageFilter CreateDropShadowOnly(float dx, float dy, float sigmaX, float sigmaY, SKColor color, SKImageFilter input, CropRect cropRect)`
  - `SKImageFilter CreateErode(int radiusX, int radiusY, SKImageFilter input, CropRect cropRect)`
  - `SKImageFilter CreateErode(float radiusX, float radiusY)`
  - `SKImageFilter CreateErode(float radiusX, float radiusY, SKImageFilter input)`
  - `SKImageFilter CreateErode(float radiusX, float radiusY, SKImageFilter input, SKRect cropRect)`
  - `SKImageFilter CreateErode(float radiusX, float radiusY, SKImageFilter input, CropRect cropRect)`
  - `SKImageFilter CreateImage(SKImage image)`
  - `SKImageFilter CreateImage(SKImage image, SKRect src, SKRect dst, SKFilterQuality filterQuality)`
  - `SKImageFilter CreateMagnifier(SKRect src, float inset)`
  - `SKImageFilter CreateMagnifier(SKRect src, float inset, SKImageFilter input)`
  - `SKImageFilter CreateMagnifier(SKRect src, float inset, SKImageFilter input, SKRect cropRect)`
  - `... (properties omitted)`

`struct SKImageInfo`
  - `SKImageInfo(int width, int height)`
  - `SKImageInfo(int width, int height, SKColorType colorType)`
  - `SKImageInfo(int width, int height, SKColorType colorType, SKAlphaType alphaType)`
  - `SKImageInfo(int width, int height, SKColorType colorType, SKAlphaType alphaType, SKColorSpace colorspace)`
  - `bool Equals(SKImageInfo obj)`
  - `bool Equals(object obj)`
  - `int GetHashCode()`
  - `SKImageInfo WithAlphaType(SKAlphaType newAlphaType)`
  - `SKImageInfo WithColorSpace(SKColorSpace newColorSpace)`
  - `SKImageInfo WithColorType(SKColorType newColorType)`
  - `SKImageInfo WithSize(SKSizeI size)`
  - `SKImageInfo WithSize(int width, int height)`
  - `SKAlphaType AlphaType { get; set; }`
  - `int BitsPerPixel { get; }`
  - `int BytesPerPixel { get; }`
  - `int BytesSize { get; }`
  - `long BytesSize64 { get; }`
  - `SKColorSpace ColorSpace { get; set; }`
  - `SKColorType ColorType { get; set; }`
  - `int Height { get; set; }`
  - `bool IsEmpty { get; }`
  - `bool IsOpaque { get; }`
  - `SKRectI Rect { get; }`
  - `int RowBytes { get; }`
  - `long RowBytes64 { get; }`
  - `SKSizeI Size { get; }`
  - `int Width { get; set; }`

`class SKImageRasterReleaseDelegate`
  - `SKImageRasterReleaseDelegate(object object, IntPtr method)`
  - `IAsyncResult BeginInvoke(IntPtr pixels, object context, AsyncCallback callback, object object)`
  - `void EndInvoke(IAsyncResult result)`
  - `void Invoke(IntPtr pixels, object context)`

`class SKImageTextureReleaseDelegate`
  - `SKImageTextureReleaseDelegate(object object, IntPtr method)`
  - `IAsyncResult BeginInvoke(object context, AsyncCallback callback, object object)`
  - `void EndInvoke(IAsyncResult result)`
  - `void Invoke(object context)`

`enum SKJpegEncoderAlphaOption`
  - `values: Ignore, BlendOnBlack`

`enum SKJpegEncoderDownsample`
  - `values: Downsample420, Downsample422, Downsample444`

`struct SKJpegEncoderOptions`
  - `SKJpegEncoderOptions(int quality, SKJpegEncoderDownsample downsample, SKJpegEncoderAlphaOption alphaOption)`
  - `SKJpegEncoderOptions(int quality, SKJpegEncoderDownsample downsample, SKJpegEncoderAlphaOption alphaOption, SKTransferFunctionBehavior blendBehavior)`
  - `bool Equals(SKJpegEncoderOptions obj)`
  - `bool Equals(object obj)`
  - `int GetHashCode()`
  - `SKJpegEncoderAlphaOption AlphaOption { get; set; }`
  - `SKTransferFunctionBehavior BlendBehavior { get; set; }`
  - `SKJpegEncoderDownsample Downsample { get; set; }`
  - `int Quality { get; set; }`

`struct SKLattice`
  - `bool Equals(SKLattice obj)`
  - `bool Equals(object obj)`
  - `int GetHashCode()`
  - `Nullable<SKRectI> Bounds { get; set; }`
  - `SKColor[] Colors { get; set; }`
  - `SKLatticeRectType[] RectTypes { get; set; }`
  - `int[] XDivs { get; set; }`
  - `int[] YDivs { get; set; }`

`enum SKLatticeRectType`
  - `values: Default, Transparent, FixedColor`

`class SKManagedPixelSerializer`
  - `SKManagedPixelSerializer()`

`class SKManagedStream`
  - `SKManagedStream(Stream managedStream)`
  - `SKManagedStream(Stream managedStream, bool disposeManagedStream)`
  - `int CopyTo(SKWStream destination)`
  - `SKStreamAsset ToMemoryStream()`

`class SKManagedWStream`
  - `SKManagedWStream(Stream managedStream)`
  - `SKManagedWStream(Stream managedStream, bool disposeManagedStream)`

`struct SKMask`
  - `SKMask(IntPtr image, SKRectI bounds, UInt32 rowBytes, SKMaskFormat format)`
  - `SKMask(SKRectI bounds, UInt32 rowBytes, SKMaskFormat format)`
  - `long AllocateImage()`
  - `IntPtr AllocateImage(long size)`
  - `long ComputeImageSize()`
  - `long ComputeTotalImageSize()`
  - `SKMask Create(byte[] image, SKRectI bounds, UInt32 rowBytes, SKMaskFormat format)`
  - `SKMask Create(ReadOnlySpan<byte> image, SKRectI bounds, UInt32 rowBytes, SKMaskFormat format)`
  - `bool Equals(SKMask obj)`
  - `bool Equals(object obj)`
  - `void FreeImage()`
  - `void FreeImage(IntPtr image)`
  - `IntPtr GetAddr(int x, int y)`
  - `byte GetAddr1(int x, int y)`
  - `UInt16 GetAddr16(int x, int y)`
  - `UInt32 GetAddr32(int x, int y)`
  - `byte GetAddr8(int x, int y)`
  - `int GetHashCode()`
  - `Span<byte> GetImageSpan()`
  - `SKRectI Bounds { get; set; }`
  - `SKMaskFormat Format { get; set; }`
  - `IntPtr Image { get; set; }`
  - `bool IsEmpty { get; }`
  - `UInt32 RowBytes { get; set; }`

`class SKMaskFilter`
  - `float ConvertRadiusToSigma(float radius)`
  - `float ConvertSigmaToRadius(float sigma)`
  - `SKMaskFilter CreateBlur(SKBlurStyle blurStyle, float sigma)`
  - `SKMaskFilter CreateBlur(SKBlurStyle blurStyle, float sigma, bool respectCTM)`
  - `SKMaskFilter CreateBlur(SKBlurStyle blurStyle, float sigma, SKBlurMaskFilterFlags flags)`
  - `SKMaskFilter CreateBlur(SKBlurStyle blurStyle, float sigma, SKRect occluder)`
  - `SKMaskFilter CreateBlur(SKBlurStyle blurStyle, float sigma, SKRect occluder, SKBlurMaskFilterFlags flags)`
  - `SKMaskFilter CreateBlur(SKBlurStyle blurStyle, float sigma, SKRect occluder, bool respectCTM)`
  - `SKMaskFilter CreateClip(byte min, byte max)`
  - `SKMaskFilter CreateGamma(float gamma)`
  - `SKMaskFilter CreateTable(byte[] table)`

`enum SKMaskFormat`
  - `values: BW, A8, ThreeD, Argb32, Lcd16, Sdf`

`struct SKMatrix`
  - `SKMatrix(float[] values)`
  - `SKMatrix(float scaleX, float skewX, float transX, float skewY, float scaleY, float transY, float persp0, float persp1, float persp2)`
  - `SKMatrix Concat(SKMatrix first, SKMatrix second)`
  - `void Concat(SKMatrix target, SKMatrix first, SKMatrix second)`
  - `void Concat(SKMatrix target, SKMatrix first, SKMatrix second)`
  - `SKMatrix CreateIdentity()`
  - `SKMatrix CreateRotation(float radians)`
  - `SKMatrix CreateRotation(float radians, float pivotX, float pivotY)`
  - `SKMatrix CreateRotationDegrees(float degrees)`
  - `SKMatrix CreateRotationDegrees(float degrees, float pivotX, float pivotY)`
  - `SKMatrix CreateScale(float x, float y)`
  - `SKMatrix CreateScale(float x, float y, float pivotX, float pivotY)`
  - `SKMatrix CreateScaleTranslation(float sx, float sy, float tx, float ty)`
  - `SKMatrix CreateSkew(float x, float y)`
  - `SKMatrix CreateTranslation(float x, float y)`
  - `bool Equals(SKMatrix obj)`
  - `bool Equals(object obj)`
  - `int GetHashCode()`
  - `void GetValues(float[] values)`
  - `SKMatrix Invert()`
  - `SKMatrix MakeIdentity()`
  - `SKMatrix MakeRotation(float radians)`
  - `SKMatrix MakeRotation(float radians, float pivotx, float pivoty)`
  - `SKMatrix MakeRotationDegrees(float degrees)`
  - `SKMatrix MakeRotationDegrees(float degrees, float pivotx, float pivoty)`
  - `SKMatrix MakeScale(float sx, float sy)`
  - `SKMatrix MakeScale(float sx, float sy, float pivotX, float pivotY)`
  - `SKMatrix MakeSkew(float sx, float sy)`
  - `SKMatrix MakeTranslation(float dx, float dy)`
  - `SKPoint MapPoint(SKPoint point)`
  - `SKPoint MapPoint(float x, float y)`
  - `void MapPoints(SKPoint[] result, SKPoint[] points)`
  - `SKPoint[] MapPoints(SKPoint[] points)`
  - `float MapRadius(float radius)`
  - `SKRect MapRect(SKRect source)`
  - `void MapRect(SKMatrix matrix, out SKRect dest, SKRect source)`
  - `SKPoint MapVector(SKPoint vector)`
  - `SKPoint MapVector(float x, float y)`
  - `void MapVectors(SKPoint[] result, SKPoint[] vectors)`
  - `SKPoint[] MapVectors(SKPoint[] vectors)`
  - `SKMatrix PostConcat(SKMatrix matrix)`
  - `void PostConcat(SKMatrix target, SKMatrix matrix)`
  - `void PostConcat(SKMatrix target, SKMatrix matrix)`
  - `SKMatrix PreConcat(SKMatrix matrix)`
  - `void PreConcat(SKMatrix target, SKMatrix matrix)`
  - `void PreConcat(SKMatrix target, SKMatrix matrix)`
  - `void Rotate(SKMatrix matrix, float radians, float pivotx, float pivoty)`
  - `void Rotate(SKMatrix matrix, float radians)`
  - `void RotateDegrees(SKMatrix matrix, float degrees, float pivotx, float pivoty)`
  - `void RotateDegrees(SKMatrix matrix, float degrees)`
  - `void SetScaleTranslate(float sx, float sy, float tx, float ty)`
  - `bool TryInvert(out SKMatrix inverse)`
  - `... (properties omitted)`

`class SKMatrix44`
  - `SKMatrix44()`
  - `SKMatrix44(SKMatrix44 src)`
  - `SKMatrix44(SKMatrix44 a, SKMatrix44 b)`
  - `SKMatrix44(SKMatrix src)`
  - `SKMatrix44 CreateIdentity()`
  - `SKMatrix44 CreateRotation(float x, float y, float z, float radians)`
  - `SKMatrix44 CreateRotationDegrees(float x, float y, float z, float degrees)`
  - `SKMatrix44 CreateScale(float x, float y, float z)`
  - `SKMatrix44 CreateTranslate(float x, float y, float z)`
  - `SKMatrix44 CreateTranslation(float x, float y, float z)`
  - `double Determinant()`
  - `bool Equal(SKMatrix44 left, SKMatrix44 right)`
  - `SKMatrix44 FromColumnMajor(float[] src)`
  - `SKMatrix44 FromRowMajor(float[] src)`
  - `SKMatrix44 Invert()`
  - `bool Invert(SKMatrix44 inverse)`
  - `SKPoint MapPoint(SKPoint src)`
  - `SKPoint[] MapPoints(SKPoint[] src)`
  - `float[] MapScalars(float x, float y, float z, float w)`
  - `float[] MapScalars(float[] srcVector4)`
  - `void MapScalars(float[] srcVector4, float[] dstVector4)`
  - `float[] MapVector2(float[] src2)`
  - `void MapVector2(float[] src2, float[] dst4)`
  - `void PostConcat(SKMatrix44 m)`
  - `void PostScale(float sx, float sy, float sz)`
  - `void PostTranslate(float dx, float dy, float dz)`
  - `void PreConcat(SKMatrix44 m)`
  - `void PreScale(float sx, float sy, float sz)`
  - `void PreTranslate(float dx, float dy, float dz)`
  - `bool Preserves2DAxisAlignment(float epsilon)`
  - `void Set3x3ColumnMajor(float[] src)`
  - `void Set3x3RowMajor(float[] src)`
  - `void SetColumnMajor(float[] src)`
  - `void SetConcat(SKMatrix44 a, SKMatrix44 b)`
  - `void SetIdentity()`
  - `void SetRotationAbout(float x, float y, float z, float radians)`
  - `void SetRotationAboutDegrees(float x, float y, float z, float degrees)`
  - `void SetRotationAboutUnit(float x, float y, float z, float radians)`
  - `void SetRowMajor(float[] src)`
  - `void SetScale(float sx, float sy, float sz)`
  - `void SetTranslate(float dx, float dy, float dz)`
  - `float[] ToColumnMajor()`
  - `void ToColumnMajor(float[] dst)`
  - `float[] ToRowMajor()`
  - `void ToRowMajor(float[] dst)`
  - `void Transpose()`
  - `bool IsInvertible { get; }`
  - `float Item { get; set; }`
  - `SKMatrix Matrix { get; }`
  - `SKMatrix44TypeMask Type { get; }`

`enum SKMatrix44TypeMask`
  - `values: Identity, Translate, Scale, Affine, Perspective`

`enum SKMatrixConvolutionTileMode`
  - `values: Clamp, Repeat, ClampToBlack`

`class SKMemoryStream`
  - `SKMemoryStream()`
  - `SKMemoryStream(UInt64 length)`
  - `SKMemoryStream(SKData data)`
  - `SKMemoryStream(byte[] data)`
  - `void SetMemory(byte[] data)`

`class SKNWayCanvas`
  - `SKNWayCanvas(int width, int height)`
  - `void AddCanvas(SKCanvas canvas)`
  - `void RemoveAll()`
  - `void RemoveCanvas(SKCanvas canvas)`

`enum SKNamedGamma`
  - `values: Linear, Srgb, TwoDotTwoCurve, NonStandard`

`class SKNativeObject`
  - `void Dispose()`
  - `IntPtr Handle { get; set; }`

`class SKNoDrawCanvas`
  - `SKNoDrawCanvas(int width, int height)`

`class SKObject`
  - `IntPtr Handle { get; set; }`

`class SKOverdrawCanvas`
  - `SKOverdrawCanvas(SKCanvas canvas)`

`struct SKPMColor`
  - `SKPMColor(UInt32 value)`
  - `bool Equals(SKPMColor obj)`
  - `bool Equals(object other)`
  - `int GetHashCode()`
  - `SKPMColor PreMultiply(SKColor color)`
  - `SKPMColor[] PreMultiply(SKColor[] colors)`
  - `string ToString()`
  - `SKColor UnPreMultiply(SKPMColor pmcolor)`
  - `SKColor[] UnPreMultiply(SKPMColor[] pmcolors)`
  - `byte Alpha { get; }`
  - `byte Blue { get; }`
  - `byte Green { get; }`
  - `byte Red { get; }`

`class SKPaint`
  - `SKPaint()`
  - `SKPaint(SKFont font)`
  - `long BreakText(string text, float maxWidth)`
  - `long BreakText(string text, float maxWidth, out float measuredWidth)`
  - `long BreakText(string text, float maxWidth, out float measuredWidth, out string measuredText)`
  - `long BreakText(ReadOnlySpan<char> text, float maxWidth)`
  - `long BreakText(ReadOnlySpan<char> text, float maxWidth, out float measuredWidth)`
  - `long BreakText(byte[] text, float maxWidth)`
  - `long BreakText(byte[] text, float maxWidth, out float measuredWidth)`
  - `long BreakText(ReadOnlySpan<byte> text, float maxWidth)`
  - `long BreakText(ReadOnlySpan<byte> text, float maxWidth, out float measuredWidth)`
  - `long BreakText(IntPtr buffer, int length, float maxWidth)`
  - `long BreakText(IntPtr buffer, int length, float maxWidth, out float measuredWidth)`
  - `long BreakText(IntPtr buffer, IntPtr length, float maxWidth)`
  - `long BreakText(IntPtr buffer, IntPtr length, float maxWidth, out float measuredWidth)`
  - `SKPaint Clone()`
  - `bool ContainsGlyphs(string text)`
  - `bool ContainsGlyphs(ReadOnlySpan<char> text)`
  - `bool ContainsGlyphs(byte[] text)`
  - `bool ContainsGlyphs(ReadOnlySpan<byte> text)`
  - `bool ContainsGlyphs(IntPtr text, int length)`
  - `bool ContainsGlyphs(IntPtr text, IntPtr length)`
  - `int CountGlyphs(string text)`
  - `int CountGlyphs(ReadOnlySpan<char> text)`
  - `int CountGlyphs(byte[] text)`
  - `int CountGlyphs(ReadOnlySpan<byte> text)`
  - `int CountGlyphs(IntPtr text, int length)`
  - `int CountGlyphs(IntPtr text, IntPtr length)`
  - `SKPath GetFillPath(SKPath src)`
  - `SKPath GetFillPath(SKPath src, float resScale)`
  - `SKPath GetFillPath(SKPath src, SKRect cullRect)`
  - `SKPath GetFillPath(SKPath src, SKRect cullRect, float resScale)`
  - `bool GetFillPath(SKPath src, SKPath dst)`
  - `bool GetFillPath(SKPath src, SKPath dst, float resScale)`
  - `bool GetFillPath(SKPath src, SKPath dst, SKRect cullRect)`
  - `bool GetFillPath(SKPath src, SKPath dst, SKRect cullRect, float resScale)`
  - `float GetFontMetrics(out SKFontMetrics metrics)`
  - `float GetFontMetrics(out SKFontMetrics metrics, float scale)`
  - `float[] GetGlyphOffsets(string text, float origin = ...)`
  - `float[] GetGlyphOffsets(ReadOnlySpan<char> text, float origin = ...)`
  - `float[] GetGlyphOffsets(ReadOnlySpan<byte> text, float origin = ...)`
  - `float[] GetGlyphOffsets(IntPtr text, int length, float origin = ...)`
  - `SKPoint[] GetGlyphPositions(string text, SKPoint origin = ...)`
  - `SKPoint[] GetGlyphPositions(ReadOnlySpan<char> text, SKPoint origin = ...)`
  - `SKPoint[] GetGlyphPositions(ReadOnlySpan<byte> text, SKPoint origin = ...)`
  - `SKPoint[] GetGlyphPositions(IntPtr text, int length, SKPoint origin = ...)`
  - `float[] GetGlyphWidths(string text)`
  - `float[] GetGlyphWidths(ReadOnlySpan<char> text)`
  - `float[] GetGlyphWidths(byte[] text)`
  - `float[] GetGlyphWidths(ReadOnlySpan<byte> text)`
  - `float[] GetGlyphWidths(IntPtr text, int length)`
  - `float[] GetGlyphWidths(IntPtr text, IntPtr length)`
  - `float[] GetGlyphWidths(string text, out SKRect[] bounds)`
  - `float[] GetGlyphWidths(ReadOnlySpan<char> text, out SKRect[] bounds)`
  - `float[] GetGlyphWidths(byte[] text, out SKRect[] bounds)`
  - `float[] GetGlyphWidths(ReadOnlySpan<byte> text, out SKRect[] bounds)`
  - `float[] GetGlyphWidths(IntPtr text, int length, out SKRect[] bounds)`
  - `float[] GetGlyphWidths(IntPtr text, IntPtr length, out SKRect[] bounds)`
  - `UInt16[] GetGlyphs(string text)`
  - `UInt16[] GetGlyphs(ReadOnlySpan<char> text)`
  - `... (properties omitted)`

`enum SKPaintHinting`
  - `values: NoHinting, Slight, Normal, Full`

`enum SKPaintStyle`
  - `values: Fill, Stroke, StrokeAndFill`

`class SKPath`
  - `SKPath()`
  - `SKPath(SKPath path)`
  - `void AddArc(SKRect oval, float startAngle, float sweepAngle)`
  - `void AddCircle(float x, float y, float radius, SKPathDirection dir = ...)`
  - `void AddOval(SKRect rect, SKPathDirection direction = ...)`
  - `void AddPath(SKPath other, float dx, float dy, SKPathAddMode mode = ...)`
  - `void AddPath(SKPath other, SKMatrix matrix, SKPathAddMode mode = ...)`
  - `void AddPath(SKPath other, SKPathAddMode mode = ...)`
  - `void AddPathReverse(SKPath other)`
  - `void AddPoly(SKPoint[] points, bool close = ...)`
  - `void AddRect(SKRect rect, SKPathDirection direction = ...)`
  - `void AddRect(SKRect rect, SKPathDirection direction, UInt32 startIndex)`
  - `void AddRoundRect(SKRoundRect rect, SKPathDirection direction = ...)`
  - `void AddRoundRect(SKRoundRect rect, SKPathDirection direction, UInt32 startIndex)`
  - `void AddRoundRect(SKRect rect, float rx, float ry, SKPathDirection dir = ...)`
  - `void AddRoundedRect(SKRect rect, float rx, float ry, SKPathDirection dir = ...)`
  - `void ArcTo(SKPoint r, float xAxisRotate, SKPathArcSize largeArc, SKPathDirection sweep, SKPoint xy)`
  - `void ArcTo(float rx, float ry, float xAxisRotate, SKPathArcSize largeArc, SKPathDirection sweep, float x, float y)`
  - `void ArcTo(SKRect oval, float startAngle, float sweepAngle, bool forceMoveTo)`
  - `void ArcTo(SKPoint point1, SKPoint point2, float radius)`
  - `void ArcTo(float x1, float y1, float x2, float y2, float radius)`
  - `void Close()`
  - `SKRect ComputeTightBounds()`
  - `void ConicTo(SKPoint point0, SKPoint point1, float w)`
  - `void ConicTo(float x0, float y0, float x1, float y1, float w)`
  - `bool Contains(float x, float y)`
  - `SKPoint[] ConvertConicToQuads(SKPoint p0, SKPoint p1, SKPoint p2, float w, int pow2)`
  - `int ConvertConicToQuads(SKPoint p0, SKPoint p1, SKPoint p2, float w, out SKPoint[] pts, int pow2)`
  - `int ConvertConicToQuads(SKPoint p0, SKPoint p1, SKPoint p2, float w, SKPoint[] pts, int pow2)`
  - `Iterator CreateIterator(bool forceClose)`
  - `RawIterator CreateRawIterator()`
  - `void CubicTo(SKPoint point0, SKPoint point1, SKPoint point2)`
  - `void CubicTo(float x0, float y0, float x1, float y1, float x2, float y2)`
  - `bool GetBounds(out SKRect rect)`
  - `SKPoint[] GetLine()`
  - `SKRect GetOvalBounds()`
  - `SKPoint GetPoint(int index)`
  - `SKPoint[] GetPoints(int max)`
  - `int GetPoints(SKPoint[] points, int max)`
  - `SKRect GetRect()`
  - `SKRect GetRect(out bool isClosed, out SKPathDirection direction)`
  - `SKRoundRect GetRoundRect()`
  - `bool GetTightBounds(out SKRect result)`
  - `void LineTo(SKPoint point)`
  - `void LineTo(float x, float y)`
  - `void MoveTo(SKPoint point)`
  - `void MoveTo(float x, float y)`
  - `void Offset(SKPoint offset)`
  - `void Offset(float dx, float dy)`
  - `bool Op(SKPath other, SKPathOp op, SKPath result)`
  - `SKPath Op(SKPath other, SKPathOp op)`
  - `SKPath ParseSvgPathData(string svgPath)`
  - `void QuadTo(SKPoint point0, SKPoint point1)`
  - `void QuadTo(float x0, float y0, float x1, float y1)`
  - `void RArcTo(SKPoint r, float xAxisRotate, SKPathArcSize largeArc, SKPathDirection sweep, SKPoint xy)`
  - `void RArcTo(float rx, float ry, float xAxisRotate, SKPathArcSize largeArc, SKPathDirection sweep, float x, float y)`
  - `void RConicTo(SKPoint point0, SKPoint point1, float w)`
  - `void RConicTo(float dx0, float dy0, float dx1, float dy1, float w)`
  - `void RCubicTo(SKPoint point0, SKPoint point1, SKPoint point2)`
  - `void RCubicTo(float dx0, float dy0, float dx1, float dy1, float dx2, float dy2)`
  - `... (properties omitted)`

`enum SKPath1DPathEffectStyle`
  - `values: Translate, Rotate, Morph`

`enum SKPathAddMode`
  - `values: Append, Extend`

`enum SKPathArcSize`
  - `values: Small, Large`

`enum SKPathConvexity`
  - `values: Unknown, Convex, Concave`

`enum SKPathDirection`
  - `values: Clockwise, CounterClockwise`

`class SKPathEffect`
  - `SKPathEffect Create1DPath(SKPath path, float advance, float phase, SKPath1DPathEffectStyle style)`
  - `SKPathEffect Create2DLine(float width, SKMatrix matrix)`
  - `SKPathEffect Create2DPath(SKMatrix matrix, SKPath path)`
  - `SKPathEffect CreateCompose(SKPathEffect outer, SKPathEffect inner)`
  - `SKPathEffect CreateCorner(float radius)`
  - `SKPathEffect CreateDash(float[] intervals, float phase)`
  - `SKPathEffect CreateDiscrete(float segLength, float deviation, UInt32 seedAssist = ...)`
  - `SKPathEffect CreateSum(SKPathEffect first, SKPathEffect second)`
  - `SKPathEffect CreateTrim(float start, float stop)`
  - `SKPathEffect CreateTrim(float start, float stop, SKTrimPathEffectMode mode)`

`enum SKPathFillType`
  - `values: Winding, EvenOdd, InverseWinding, InverseEvenOdd`

`class SKPathMeasure`
  - `SKPathMeasure()`
  - `SKPathMeasure(SKPath path, bool forceClosed = ..., float resScale = ...)`
  - `SKMatrix GetMatrix(float distance, SKPathMeasureMatrixFlags flags)`
  - `bool GetMatrix(float distance, out SKMatrix matrix, SKPathMeasureMatrixFlags flags)`
  - `SKPoint GetPosition(float distance)`
  - `bool GetPosition(float distance, out SKPoint position)`
  - `bool GetPositionAndTangent(float distance, out SKPoint position, out SKPoint tangent)`
  - `bool GetSegment(float start, float stop, SKPath dst, bool startWithMoveTo)`
  - `SKPath GetSegment(float start, float stop, bool startWithMoveTo)`
  - `SKPoint GetTangent(float distance)`
  - `bool GetTangent(float distance, out SKPoint tangent)`
  - `bool NextContour()`
  - `void SetPath(SKPath path)`
  - `void SetPath(SKPath path, bool forceClosed)`
  - `bool IsClosed { get; }`
  - `float Length { get; }`

`enum SKPathMeasureMatrixFlags`
  - `values: GetPosition, GetTangent, GetPositionAndTangent`

`enum SKPathOp`
  - `values: Difference, Intersect, Union, Xor, ReverseDifference`

`enum SKPathSegmentMask`
  - `values: Line, Quad, Conic, Cubic`

`enum SKPathVerb`
  - `values: Move, Line, Quad, Conic, Cubic, Close, Done`

`class SKPicture`
  - `SKPicture Deserialize(IntPtr data, int length)`
  - `SKPicture Deserialize(ReadOnlySpan<byte> data)`
  - `SKPicture Deserialize(SKData data)`
  - `SKPicture Deserialize(Stream stream)`
  - `SKPicture Deserialize(SKStream stream)`
  - `SKData Serialize()`
  - `void Serialize(Stream stream)`
  - `void Serialize(SKWStream stream)`
  - `SKShader ToShader()`
  - `SKShader ToShader(SKShaderTileMode tmx, SKShaderTileMode tmy)`
  - `SKShader ToShader(SKShaderTileMode tmx, SKShaderTileMode tmy, SKRect tile)`
  - `SKShader ToShader(SKShaderTileMode tmx, SKShaderTileMode tmy, SKMatrix localMatrix, SKRect tile)`
  - `SKRect CullRect { get; }`
  - `UInt32 UniqueId { get; }`

`class SKPictureRecorder`
  - `SKPictureRecorder()`
  - `SKCanvas BeginRecording(SKRect cullRect)`
  - `SKPicture EndRecording()`
  - `SKDrawable EndRecordingAsDrawable()`
  - `SKCanvas RecordingCanvas { get; }`

`enum SKPixelGeometry`
  - `values: Unknown, RgbHorizontal, BgrHorizontal, RgbVertical, BgrVertical`

`class SKPixelSerializer`
  - `SKPixelSerializer Create(Func<SKPixmap, SKData> onEncode)`
  - `SKPixelSerializer Create(Func<IntPtr, IntPtr, bool> onUseEncodedData, Func<SKPixmap, SKData> onEncode)`
  - `SKData Encode(SKPixmap pixmap)`
  - `bool UseEncodedData(IntPtr data, UInt64 length)`

`class SKPixmap`
  - `SKPixmap()`
  - `SKPixmap(SKImageInfo info, IntPtr addr)`
  - `SKPixmap(SKImageInfo info, IntPtr addr, int rowBytes, SKColorTable ctable)`
  - `SKPixmap(SKImageInfo info, IntPtr addr, int rowBytes)`
  - `SKData Encode(SKEncodedImageFormat encoder, int quality)`
  - `bool Encode(Stream dst, SKEncodedImageFormat encoder, int quality)`
  - `bool Encode(SKWStream dst, SKEncodedImageFormat encoder, int quality)`
  - `bool Encode(SKWStream dst, SKBitmap src, SKEncodedImageFormat format, int quality)`
  - `bool Encode(SKWStream dst, SKPixmap src, SKEncodedImageFormat encoder, int quality)`
  - `SKData Encode(SKWebpEncoderOptions options)`
  - `bool Encode(Stream dst, SKWebpEncoderOptions options)`
  - `bool Encode(SKWStream dst, SKWebpEncoderOptions options)`
  - `bool Encode(SKWStream dst, SKPixmap src, SKWebpEncoderOptions options)`
  - `SKData Encode(SKJpegEncoderOptions options)`
  - `bool Encode(Stream dst, SKJpegEncoderOptions options)`
  - `bool Encode(SKWStream dst, SKJpegEncoderOptions options)`
  - `bool Encode(SKWStream dst, SKPixmap src, SKJpegEncoderOptions options)`
  - `SKData Encode(SKPngEncoderOptions options)`
  - `bool Encode(Stream dst, SKPngEncoderOptions options)`
  - `bool Encode(SKWStream dst, SKPngEncoderOptions options)`
  - `bool Encode(SKWStream dst, SKPixmap src, SKPngEncoderOptions options)`
  - `bool Erase(SKColor color)`
  - `bool Erase(SKColor color, SKRectI subset)`
  - `bool Erase(SKColorF color)`
  - `bool Erase(SKColorF color, SKRectI subset)`
  - `bool Erase(SKColorF color, SKColorSpace colorspace, SKRectI subset)`
  - `SKPixmap ExtractSubset(SKRectI subset)`
  - `bool ExtractSubset(SKPixmap result, SKRectI subset)`
  - `SKColor GetPixelColor(int x, int y)`
  - `ReadOnlySpan<byte> GetPixelSpan()`
  - `Span<T> GetPixelSpan<T>()`
  - `IntPtr GetPixels()`
  - `IntPtr GetPixels(int x, int y)`
  - `bool ReadPixels(SKImageInfo dstInfo, IntPtr dstPixels, int dstRowBytes, int srcX, int srcY, SKTransferFunctionBehavior behavior)`
  - `bool ReadPixels(SKImageInfo dstInfo, IntPtr dstPixels, int dstRowBytes, int srcX, int srcY)`
  - `bool ReadPixels(SKImageInfo dstInfo, IntPtr dstPixels, int dstRowBytes)`
  - `bool ReadPixels(SKPixmap pixmap, int srcX, int srcY)`
  - `bool ReadPixels(SKPixmap pixmap)`
  - `void Reset()`
  - `void Reset(SKImageInfo info, IntPtr addr, int rowBytes, SKColorTable ctable)`
  - `void Reset(SKImageInfo info, IntPtr addr, int rowBytes)`
  - `bool Resize(SKPixmap dst, SKPixmap src, SKBitmapResizeMethod method)`
  - `bool ScalePixels(SKPixmap destination, SKFilterQuality quality)`
  - `SKPixmap WithAlphaType(SKAlphaType newAlphaType)`
  - `SKPixmap WithColorSpace(SKColorSpace newColorSpace)`
  - `SKPixmap WithColorType(SKColorType newColorType)`
  - `SKAlphaType AlphaType { get; }`
  - `int BytesPerPixel { get; }`
  - `int BytesSize { get; }`
  - `SKColorSpace ColorSpace { get; }`
  - `SKColorTable ColorTable { get; }`
  - `SKColorType ColorType { get; }`
  - `int Height { get; }`
  - `SKImageInfo Info { get; }`
  - `SKRectI Rect { get; }`
  - `int RowBytes { get; }`
  - `SKSizeI Size { get; }`
  - `int Width { get; }`

`enum SKPngEncoderFilterFlags`
  - `values: NoFilters, None, Sub, Up, Avg, Paeth, AllFilters`

`struct SKPngEncoderOptions`
  - `SKPngEncoderOptions(SKPngEncoderFilterFlags filterFlags, int zLibLevel)`
  - `SKPngEncoderOptions(SKPngEncoderFilterFlags filterFlags, int zLibLevel, SKTransferFunctionBehavior unpremulBehavior)`
  - `bool Equals(SKPngEncoderOptions obj)`
  - `bool Equals(object obj)`
  - `int GetHashCode()`
  - `SKPngEncoderFilterFlags FilterFlags { get; set; }`
  - `SKTransferFunctionBehavior UnpremulBehavior { get; set; }`
  - `int ZLibLevel { get; set; }`

`struct SKPoint`
  - `SKPoint(float x, float y)`
  - `SKPoint Add(SKPoint pt, SKSizeI sz)`
  - `SKPoint Add(SKPoint pt, SKSize sz)`
  - `SKPoint Add(SKPoint pt, SKPointI sz)`
  - `SKPoint Add(SKPoint pt, SKPoint sz)`
  - `float Distance(SKPoint point, SKPoint other)`
  - `float DistanceSquared(SKPoint point, SKPoint other)`
  - `bool Equals(SKPoint obj)`
  - `bool Equals(object obj)`
  - `int GetHashCode()`
  - `SKPoint Normalize(SKPoint point)`
  - `void Offset(SKPoint p)`
  - `void Offset(float dx, float dy)`
  - `SKPoint Reflect(SKPoint point, SKPoint normal)`
  - `SKPoint Subtract(SKPoint pt, SKSizeI sz)`
  - `SKPoint Subtract(SKPoint pt, SKSize sz)`
  - `SKPoint Subtract(SKPoint pt, SKPointI sz)`
  - `SKPoint Subtract(SKPoint pt, SKPoint sz)`
  - `string ToString()`
  - `bool IsEmpty { get; }`
  - `float Length { get; }`
  - `float LengthSquared { get; }`
  - `float X { get; set; }`
  - `float Y { get; set; }`

`struct SKPoint3`
  - `SKPoint3(float x, float y, float z)`
  - `SKPoint3 Add(SKPoint3 pt, SKPoint3 sz)`
  - `bool Equals(SKPoint3 obj)`
  - `bool Equals(object obj)`
  - `int GetHashCode()`
  - `SKPoint3 Subtract(SKPoint3 pt, SKPoint3 sz)`
  - `string ToString()`
  - `bool IsEmpty { get; }`
  - `float X { get; set; }`
  - `float Y { get; set; }`
  - `float Z { get; set; }`

`struct SKPointI`
  - `SKPointI(SKSizeI sz)`
  - `SKPointI(int x, int y)`
  - `SKPointI Add(SKPointI pt, SKSizeI sz)`
  - `SKPointI Add(SKPointI pt, SKPointI sz)`
  - `SKPointI Ceiling(SKPoint value)`
  - `float Distance(SKPointI point, SKPointI other)`
  - `float DistanceSquared(SKPointI point, SKPointI other)`
  - `bool Equals(SKPointI obj)`
  - `bool Equals(object obj)`
  - `int GetHashCode()`
  - `SKPointI Normalize(SKPointI point)`
  - `void Offset(SKPointI p)`
  - `void Offset(int dx, int dy)`
  - `SKPointI Reflect(SKPointI point, SKPointI normal)`
  - `SKPointI Round(SKPoint value)`
  - `SKPointI Subtract(SKPointI pt, SKSizeI sz)`
  - `SKPointI Subtract(SKPointI pt, SKPointI sz)`
  - `string ToString()`
  - `SKPointI Truncate(SKPoint value)`
  - `bool IsEmpty { get; }`
  - `int Length { get; }`
  - `int LengthSquared { get; }`
  - `int X { get; set; }`
  - `int Y { get; set; }`

`enum SKPointMode`
  - `values: Points, Lines, Polygon`

`class SKPositionedRunBuffer`
  - `Span<SKPoint> GetPositionSpan()`
  - `void SetPositions(ReadOnlySpan<SKPoint> positions)`

`struct SKRect`
  - `SKRect(float left, float top, float right, float bottom)`
  - `SKRect AspectFill(SKSize size)`
  - `SKRect AspectFit(SKSize size)`
  - `bool Contains(float x, float y)`
  - `bool Contains(SKPoint pt)`
  - `bool Contains(SKRect rect)`
  - `SKRect Create(SKPoint location, SKSize size)`
  - `SKRect Create(SKSize size)`
  - `SKRect Create(float width, float height)`
  - `SKRect Create(float x, float y, float width, float height)`
  - `bool Equals(SKRect obj)`
  - `bool Equals(object obj)`
  - `int GetHashCode()`
  - `SKRect Inflate(SKRect rect, float x, float y)`
  - `void Inflate(SKSize size)`
  - `void Inflate(float x, float y)`
  - `SKRect Intersect(SKRect a, SKRect b)`
  - `void Intersect(SKRect rect)`
  - `bool IntersectsWith(SKRect rect)`
  - `bool IntersectsWithInclusive(SKRect rect)`
  - `void Offset(float x, float y)`
  - `void Offset(SKPoint pos)`
  - `string ToString()`
  - `SKRect Union(SKRect a, SKRect b)`
  - `void Union(SKRect rect)`
  - `float Bottom { get; set; }`
  - `float Height { get; }`
  - `bool IsEmpty { get; }`
  - `float Left { get; set; }`
  - `SKPoint Location { get; set; }`
  - `float MidX { get; }`
  - `float MidY { get; }`
  - `float Right { get; set; }`
  - `SKSize Size { get; set; }`
  - `SKRect Standardized { get; }`
  - `float Top { get; set; }`
  - `float Width { get; }`

`struct SKRectI`
  - `SKRectI(int left, int top, int right, int bottom)`
  - `SKRectI AspectFill(SKSizeI size)`
  - `SKRectI AspectFit(SKSizeI size)`
  - `SKRectI Ceiling(SKRect value)`
  - `SKRectI Ceiling(SKRect value, bool outwards)`
  - `bool Contains(int x, int y)`
  - `bool Contains(SKPointI pt)`
  - `bool Contains(SKRectI rect)`
  - `SKRectI Create(SKSizeI size)`
  - `SKRectI Create(SKPointI location, SKSizeI size)`
  - `SKRectI Create(int width, int height)`
  - `SKRectI Create(int x, int y, int width, int height)`
  - `bool Equals(SKRectI obj)`
  - `bool Equals(object obj)`
  - `SKRectI Floor(SKRect value)`
  - `SKRectI Floor(SKRect value, bool inwards)`
  - `int GetHashCode()`
  - `SKRectI Inflate(SKRectI rect, int x, int y)`
  - `void Inflate(SKSizeI size)`
  - `void Inflate(int width, int height)`
  - `SKRectI Intersect(SKRectI a, SKRectI b)`
  - `void Intersect(SKRectI rect)`
  - `bool IntersectsWith(SKRectI rect)`
  - `bool IntersectsWithInclusive(SKRectI rect)`
  - `void Offset(int x, int y)`
  - `void Offset(SKPointI pos)`
  - `SKRectI Round(SKRect value)`
  - `string ToString()`
  - `SKRectI Truncate(SKRect value)`
  - `SKRectI Union(SKRectI a, SKRectI b)`
  - `void Union(SKRectI rect)`
  - `int Bottom { get; set; }`
  - `int Height { get; }`
  - `bool IsEmpty { get; }`
  - `int Left { get; set; }`
  - `SKPointI Location { get; set; }`
  - `int MidX { get; }`
  - `int MidY { get; }`
  - `int Right { get; set; }`
  - `SKSizeI Size { get; set; }`
  - `SKRectI Standardized { get; }`
  - `int Top { get; set; }`
  - `int Width { get; }`

`class SKRegion`
  - `SKRegion()`
  - `SKRegion(SKRegion region)`
  - `SKRegion(SKRectI rect)`
  - `SKRegion(SKPath path)`
  - `bool Contains(SKPath path)`
  - `bool Contains(SKRegion src)`
  - `bool Contains(SKPointI xy)`
  - `bool Contains(int x, int y)`
  - `bool Contains(SKRectI rect)`
  - `ClipIterator CreateClipIterator(SKRectI clip)`
  - `RectIterator CreateRectIterator()`
  - `SpanIterator CreateSpanIterator(int y, int left, int right)`
  - `SKPath GetBoundaryPath()`
  - `bool Intersects(SKPath path)`
  - `bool Intersects(SKRegion region)`
  - `bool Intersects(SKRectI rect)`
  - `bool Op(SKRectI rect, SKRegionOperation op)`
  - `bool Op(int left, int top, int right, int bottom, SKRegionOperation op)`
  - `bool Op(SKRegion region, SKRegionOperation op)`
  - `bool Op(SKPath path, SKRegionOperation op)`
  - `bool QuickContains(SKRectI rect)`
  - `bool QuickReject(SKRectI rect)`
  - `bool QuickReject(SKRegion region)`
  - `bool QuickReject(SKPath path)`
  - `void SetEmpty()`
  - `bool SetPath(SKPath path, SKRegion clip)`
  - `bool SetPath(SKPath path)`
  - `bool SetRect(SKRectI rect)`
  - `bool SetRects(SKRectI[] rects)`
  - `bool SetRegion(SKRegion region)`
  - `void Translate(int x, int y)`
  - `SKRectI Bounds { get; }`
  - `bool IsComplex { get; }`
  - `bool IsEmpty { get; }`
  - `bool IsRect { get; }`

`enum SKRegionOperation`
  - `values: Difference, Intersect, Union, XOR, ReverseDifference, Replace`

`struct SKRotationScaleMatrix`
  - `SKRotationScaleMatrix(float scos, float ssin, float tx, float ty)`
  - `SKRotationScaleMatrix Create(float scale, float radians, float tx, float ty, float anchorX, float anchorY)`
  - `SKRotationScaleMatrix CreateDegrees(float scale, float degrees, float tx, float ty, float anchorX, float anchorY)`
  - `SKRotationScaleMatrix CreateIdentity()`
  - `SKRotationScaleMatrix CreateRotation(float radians, float anchorX, float anchorY)`
  - `SKRotationScaleMatrix CreateRotationDegrees(float degrees, float anchorX, float anchorY)`
  - `SKRotationScaleMatrix CreateScale(float s)`
  - `SKRotationScaleMatrix CreateTranslation(float x, float y)`
  - `bool Equals(SKRotationScaleMatrix obj)`
  - `bool Equals(object obj)`
  - `int GetHashCode()`
  - `SKMatrix ToMatrix()`
  - `float SCos { get; set; }`
  - `float SSin { get; set; }`
  - `float TX { get; set; }`
  - `float TY { get; set; }`

`class SKRotationScaleRunBuffer`
  - `Span<SKRotationScaleMatrix> GetRotationScaleSpan()`
  - `void SetRotationScale(ReadOnlySpan<SKRotationScaleMatrix> positions)`

`class SKRoundRect`
  - `SKRoundRect()`
  - `SKRoundRect(SKRect rect)`
  - `SKRoundRect(SKRect rect, float radius)`
  - `SKRoundRect(SKRect rect, float xRadius, float yRadius)`
  - `SKRoundRect(SKRoundRect rrect)`
  - `bool CheckAllCornersCircular(float tolerance)`
  - `bool Contains(SKRect rect)`
  - `void Deflate(SKSize size)`
  - `void Deflate(float dx, float dy)`
  - `SKPoint GetRadii(SKRoundRectCorner corner)`
  - `void Inflate(SKSize size)`
  - `void Inflate(float dx, float dy)`
  - `void Offset(SKPoint pos)`
  - `void Offset(float dx, float dy)`
  - `void SetEmpty()`
  - `void SetNinePatch(SKRect rect, float leftRadius, float topRadius, float rightRadius, float bottomRadius)`
  - `void SetOval(SKRect rect)`
  - `void SetRect(SKRect rect)`
  - `void SetRect(SKRect rect, float xRadius, float yRadius)`
  - `void SetRectRadii(SKRect rect, SKPoint[] radii)`
  - `SKRoundRect Transform(SKMatrix matrix)`
  - `bool TryTransform(SKMatrix matrix, out SKRoundRect transformed)`
  - `bool AllCornersCircular { get; }`
  - `float Height { get; }`
  - `bool IsValid { get; }`
  - `SKPoint[] Radii { get; }`
  - `SKRect Rect { get; }`
  - `SKRoundRectType Type { get; }`
  - `float Width { get; }`

`enum SKRoundRectCorner`
  - `values: UpperLeft, UpperRight, LowerRight, LowerLeft`

`enum SKRoundRectType`
  - `values: Empty, Rect, Oval, Simple, NinePatch, Complex`

`class SKRunBuffer`
  - `Span<UInt32> GetClusterSpan()`
  - `Span<UInt16> GetGlyphSpan()`
  - `Span<byte> GetTextSpan()`
  - `void SetClusters(ReadOnlySpan<UInt32> clusters)`
  - `void SetGlyphs(ReadOnlySpan<UInt16> glyphs)`
  - `void SetText(ReadOnlySpan<byte> text)`
  - `int Size { get; }`
  - `int TextSize { get; }`

`class SKRuntimeEffect`
  - `SKRuntimeEffect Create(string sksl, out string errors)`
  - `SKColorFilter ToColorFilter()`
  - `SKColorFilter ToColorFilter(SKRuntimeEffectUniforms uniforms)`
  - `SKColorFilter ToColorFilter(SKRuntimeEffectUniforms uniforms, SKRuntimeEffectChildren children)`
  - `SKShader ToShader(bool isOpaque)`
  - `SKShader ToShader(bool isOpaque, SKRuntimeEffectUniforms uniforms)`
  - `SKShader ToShader(bool isOpaque, SKRuntimeEffectUniforms uniforms, SKRuntimeEffectChildren children)`
  - `SKShader ToShader(bool isOpaque, SKRuntimeEffectUniforms uniforms, SKRuntimeEffectChildren children, SKMatrix localMatrix)`
  - `IReadOnlyList<string> Children { get; }`
  - `int UniformSize { get; }`
  - `IReadOnlyList<string> Uniforms { get; }`

`class SKRuntimeEffectChildren`
  - `SKRuntimeEffectChildren(SKRuntimeEffect effect)`
  - `void Add(string name, SKShader value)`
  - `bool Contains(string name)`
  - `IEnumerator<string> GetEnumerator()`
  - `void Reset()`
  - `SKShader[] ToArray()`
  - `int Count { get; }`
  - `SKShader Item { set; }`
  - `IReadOnlyList<string> Names { get; }`

`struct SKRuntimeEffectUniform`
  - `void WriteTo(Span<byte> data)`
  - `SKRuntimeEffectUniform Empty { get; }`
  - `bool IsEmpty { get; }`
  - `int Size { get; }`

`class SKRuntimeEffectUniforms`
  - `SKRuntimeEffectUniforms(SKRuntimeEffect effect)`
  - `void Add(string name, SKRuntimeEffectUniform value)`
  - `bool Contains(string name)`
  - `IEnumerator<string> GetEnumerator()`
  - `void Reset()`
  - `SKData ToData()`
  - `int Count { get; }`
  - `SKRuntimeEffectUniform Item { set; }`
  - `IReadOnlyList<string> Names { get; }`

`class SKShader`
  - `SKShader CreateBitmap(SKBitmap src)`
  - `SKShader CreateBitmap(SKBitmap src, SKShaderTileMode tmx, SKShaderTileMode tmy)`
  - `SKShader CreateBitmap(SKBitmap src, SKShaderTileMode tmx, SKShaderTileMode tmy, SKMatrix localMatrix)`
  - `SKShader CreateColor(SKColor color)`
  - `SKShader CreateColor(SKColorF color, SKColorSpace colorspace)`
  - `SKShader CreateColorFilter(SKShader shader, SKColorFilter filter)`
  - `SKShader CreateCompose(SKShader shaderA, SKShader shaderB)`
  - `SKShader CreateCompose(SKShader shaderA, SKShader shaderB, SKBlendMode mode)`
  - `SKShader CreateEmpty()`
  - `SKShader CreateImage(SKImage src)`
  - `SKShader CreateImage(SKImage src, SKShaderTileMode tmx, SKShaderTileMode tmy)`
  - `SKShader CreateImage(SKImage src, SKShaderTileMode tmx, SKShaderTileMode tmy, SKMatrix localMatrix)`
  - `SKShader CreateLerp(float weight, SKShader dst, SKShader src)`
  - `SKShader CreateLinearGradient(SKPoint start, SKPoint end, SKColor[] colors, SKShaderTileMode mode)`
  - `SKShader CreateLinearGradient(SKPoint start, SKPoint end, SKColor[] colors, float[] colorPos, SKShaderTileMode mode)`
  - `SKShader CreateLinearGradient(SKPoint start, SKPoint end, SKColor[] colors, float[] colorPos, SKShaderTileMode mode, SKMatrix localMatrix)`
  - `SKShader CreateLinearGradient(SKPoint start, SKPoint end, SKColorF[] colors, SKColorSpace colorspace, SKShaderTileMode mode)`
  - `SKShader CreateLinearGradient(SKPoint start, SKPoint end, SKColorF[] colors, SKColorSpace colorspace, float[] colorPos, SKShaderTileMode mode)`
  - `SKShader CreateLinearGradient(SKPoint start, SKPoint end, SKColorF[] colors, SKColorSpace colorspace, float[] colorPos, SKShaderTileMode mode, SKMatrix localMatrix)`
  - `SKShader CreateLocalMatrix(SKShader shader, SKMatrix localMatrix)`
  - `SKShader CreatePerlinNoiseFractalNoise(float baseFrequencyX, float baseFrequencyY, int numOctaves, float seed)`
  - `SKShader CreatePerlinNoiseFractalNoise(float baseFrequencyX, float baseFrequencyY, int numOctaves, float seed, SKPointI tileSize)`
  - `SKShader CreatePerlinNoiseFractalNoise(float baseFrequencyX, float baseFrequencyY, int numOctaves, float seed, SKSizeI tileSize)`
  - `SKShader CreatePerlinNoiseImprovedNoise(float baseFrequencyX, float baseFrequencyY, int numOctaves, float z)`
  - `SKShader CreatePerlinNoiseTurbulence(float baseFrequencyX, float baseFrequencyY, int numOctaves, float seed)`
  - `SKShader CreatePerlinNoiseTurbulence(float baseFrequencyX, float baseFrequencyY, int numOctaves, float seed, SKPointI tileSize)`
  - `SKShader CreatePerlinNoiseTurbulence(float baseFrequencyX, float baseFrequencyY, int numOctaves, float seed, SKSizeI tileSize)`
  - `SKShader CreatePicture(SKPicture src)`
  - `SKShader CreatePicture(SKPicture src, SKShaderTileMode tmx, SKShaderTileMode tmy)`
  - `SKShader CreatePicture(SKPicture src, SKShaderTileMode tmx, SKShaderTileMode tmy, SKRect tile)`
  - `SKShader CreatePicture(SKPicture src, SKShaderTileMode tmx, SKShaderTileMode tmy, SKMatrix localMatrix, SKRect tile)`
  - `SKShader CreateRadialGradient(SKPoint center, float radius, SKColor[] colors, SKShaderTileMode mode)`
  - `SKShader CreateRadialGradient(SKPoint center, float radius, SKColor[] colors, float[] colorPos, SKShaderTileMode mode)`
  - `SKShader CreateRadialGradient(SKPoint center, float radius, SKColor[] colors, float[] colorPos, SKShaderTileMode mode, SKMatrix localMatrix)`
  - `SKShader CreateRadialGradient(SKPoint center, float radius, SKColorF[] colors, SKColorSpace colorspace, SKShaderTileMode mode)`
  - `SKShader CreateRadialGradient(SKPoint center, float radius, SKColorF[] colors, SKColorSpace colorspace, float[] colorPos, SKShaderTileMode mode)`
  - `SKShader CreateRadialGradient(SKPoint center, float radius, SKColorF[] colors, SKColorSpace colorspace, float[] colorPos, SKShaderTileMode mode, SKMatrix localMatrix)`
  - `SKShader CreateSweepGradient(SKPoint center, SKColor[] colors)`
  - `SKShader CreateSweepGradient(SKPoint center, SKColor[] colors, float[] colorPos)`
  - `SKShader CreateSweepGradient(SKPoint center, SKColor[] colors, float[] colorPos, SKMatrix localMatrix)`
  - `SKShader CreateSweepGradient(SKPoint center, SKColor[] colors, SKShaderTileMode tileMode, float startAngle, float endAngle)`
  - `SKShader CreateSweepGradient(SKPoint center, SKColor[] colors, float[] colorPos, SKShaderTileMode tileMode, float startAngle, float endAngle)`
  - `SKShader CreateSweepGradient(SKPoint center, SKColor[] colors, float[] colorPos, SKShaderTileMode tileMode, float startAngle, float endAngle, SKMatrix localMatrix)`
  - `SKShader CreateSweepGradient(SKPoint center, SKColorF[] colors, SKColorSpace colorspace)`
  - `SKShader CreateSweepGradient(SKPoint center, SKColorF[] colors, SKColorSpace colorspace, float[] colorPos)`
  - `SKShader CreateSweepGradient(SKPoint center, SKColorF[] colors, SKColorSpace colorspace, float[] colorPos, SKMatrix localMatrix)`
  - `SKShader CreateSweepGradient(SKPoint center, SKColorF[] colors, SKColorSpace colorspace, SKShaderTileMode tileMode, float startAngle, float endAngle)`
  - `SKShader CreateSweepGradient(SKPoint center, SKColorF[] colors, SKColorSpace colorspace, float[] colorPos, SKShaderTileMode tileMode, float startAngle, float endAngle)`
  - `SKShader CreateSweepGradient(SKPoint center, SKColorF[] colors, SKColorSpace colorspace, float[] colorPos, SKShaderTileMode tileMode, float startAngle, float endAngle, SKMatrix localMatrix)`
  - `SKShader CreateTwoPointConicalGradient(SKPoint start, float startRadius, SKPoint end, float endRadius, SKColor[] colors, SKShaderTileMode mode)`
  - `SKShader CreateTwoPointConicalGradient(SKPoint start, float startRadius, SKPoint end, float endRadius, SKColor[] colors, float[] colorPos, SKShaderTileMode mode)`
  - `SKShader CreateTwoPointConicalGradient(SKPoint start, float startRadius, SKPoint end, float endRadius, SKColor[] colors, float[] colorPos, SKShaderTileMode mode, SKMatrix localMatrix)`
  - `SKShader CreateTwoPointConicalGradient(SKPoint start, float startRadius, SKPoint end, float endRadius, SKColorF[] colors, SKColorSpace colorspace, SKShaderTileMode mode)`
  - `SKShader CreateTwoPointConicalGradient(SKPoint start, float startRadius, SKPoint end, float endRadius, SKColorF[] colors, SKColorSpace colorspace, float[] colorPos, SKShaderTileMode mode)`
  - `SKShader CreateTwoPointConicalGradient(SKPoint start, float startRadius, SKPoint end, float endRadius, SKColorF[] colors, SKColorSpace colorspace, float[] colorPos, SKShaderTileMode mode, SKMatrix localMatrix)`
  - `SKShader WithColorFilter(SKColorFilter filter)`
  - `SKShader WithLocalMatrix(SKMatrix localMatrix)`

`enum SKShaderTileMode`
  - `values: Clamp, Repeat, Mirror, Decal`

`struct SKSize`
  - `SKSize(float width, float height)`
  - `SKSize(SKPoint pt)`
  - `SKSize Add(SKSize sz1, SKSize sz2)`
  - `bool Equals(SKSize obj)`
  - `bool Equals(object obj)`
  - `int GetHashCode()`
  - `SKSize Subtract(SKSize sz1, SKSize sz2)`
  - `SKPoint ToPoint()`
  - `SKSizeI ToSizeI()`
  - `string ToString()`
  - `float Height { get; set; }`
  - `bool IsEmpty { get; }`
  - `float Width { get; set; }`

`struct SKSizeI`
  - `SKSizeI(int width, int height)`
  - `SKSizeI(SKPointI pt)`
  - `SKSizeI Add(SKSizeI sz1, SKSizeI sz2)`
  - `bool Equals(SKSizeI obj)`
  - `bool Equals(object obj)`
  - `int GetHashCode()`
  - `SKSizeI Subtract(SKSizeI sz1, SKSizeI sz2)`
  - `SKPointI ToPointI()`
  - `string ToString()`
  - `int Height { get; set; }`
  - `bool IsEmpty { get; }`
  - `int Width { get; set; }`

`class SKStream`
  - `IntPtr GetMemoryBase()`
  - `bool Move(long offset)`
  - `bool Move(int offset)`
  - `int Peek(IntPtr buffer, int size)`
  - `int Read(byte[] buffer, int size)`
  - `int Read(IntPtr buffer, int size)`
  - `bool ReadBool()`
  - `bool ReadBool(out bool buffer)`
  - `byte ReadByte()`
  - `bool ReadByte(out byte buffer)`
  - `Int16 ReadInt16()`
  - `bool ReadInt16(out Int16 buffer)`
  - `int ReadInt32()`
  - `bool ReadInt32(out int buffer)`
  - `SByte ReadSByte()`
  - `bool ReadSByte(out SByte buffer)`
  - `UInt16 ReadUInt16()`
  - `bool ReadUInt16(out UInt16 buffer)`
  - `UInt32 ReadUInt32()`
  - `bool ReadUInt32(out UInt32 buffer)`
  - `bool Rewind()`
  - `bool Seek(int position)`
  - `int Skip(int size)`
  - `bool HasLength { get; }`
  - `bool HasPosition { get; }`
  - `bool IsAtEnd { get; }`
  - `int Length { get; }`
  - `int Position { get; set; }`

`enum SKStrokeCap`
  - `values: Butt, Round, Square`

`enum SKStrokeJoin`
  - `values: Miter, Round, Bevel`

`class SKSurface`
  - `SKSurface Create(int width, int height, SKColorType colorType, SKAlphaType alphaType)`
  - `SKSurface Create(int width, int height, SKColorType colorType, SKAlphaType alphaType, SKSurfaceProps props)`
  - `SKSurface Create(int width, int height, SKColorType colorType, SKAlphaType alphaType, IntPtr pixels, int rowBytes)`
  - `SKSurface Create(int width, int height, SKColorType colorType, SKAlphaType alphaType, IntPtr pixels, int rowBytes, SKSurfaceProps props)`
  - `SKSurface Create(SKImageInfo info, SKSurfaceProps props)`
  - `SKSurface Create(SKImageInfo info)`
  - `SKSurface Create(SKImageInfo info, int rowBytes)`
  - `SKSurface Create(SKImageInfo info, SKSurfaceProperties props)`
  - `SKSurface Create(SKImageInfo info, int rowBytes, SKSurfaceProperties props)`
  - `SKSurface Create(SKPixmap pixmap, SKSurfaceProps props)`
  - `SKSurface Create(SKPixmap pixmap)`
  - `SKSurface Create(SKPixmap pixmap, SKSurfaceProperties props)`
  - `SKSurface Create(SKImageInfo info, IntPtr pixels, int rowBytes, SKSurfaceProps props)`
  - `SKSurface Create(SKImageInfo info, IntPtr pixels)`
  - `SKSurface Create(SKImageInfo info, IntPtr pixels, int rowBytes)`
  - `SKSurface Create(SKImageInfo info, IntPtr pixels, int rowBytes, SKSurfaceReleaseDelegate releaseProc, object context)`
  - `SKSurface Create(SKImageInfo info, IntPtr pixels, SKSurfaceProperties props)`
  - `SKSurface Create(SKImageInfo info, IntPtr pixels, int rowBytes, SKSurfaceProperties props)`
  - `SKSurface Create(SKImageInfo info, IntPtr pixels, int rowBytes, SKSurfaceReleaseDelegate releaseProc, object context, SKSurfaceProperties props)`
  - `SKSurface Create(GRContext context, GRBackendRenderTargetDesc desc)`
  - `SKSurface Create(GRContext context, GRBackendRenderTargetDesc desc, SKSurfaceProps props)`
  - `SKSurface Create(GRContext context, GRBackendRenderTarget renderTarget, SKColorType colorType)`
  - `SKSurface Create(GRContext context, GRBackendRenderTarget renderTarget, GRSurfaceOrigin origin, SKColorType colorType)`
  - `SKSurface Create(GRContext context, GRBackendRenderTarget renderTarget, GRSurfaceOrigin origin, SKColorType colorType, SKColorSpace colorspace)`
  - `SKSurface Create(GRContext context, GRBackendRenderTarget renderTarget, SKColorType colorType, SKSurfaceProperties props)`
  - `SKSurface Create(GRContext context, GRBackendRenderTarget renderTarget, GRSurfaceOrigin origin, SKColorType colorType, SKSurfaceProperties props)`
  - `SKSurface Create(GRContext context, GRBackendRenderTarget renderTarget, GRSurfaceOrigin origin, SKColorType colorType, SKColorSpace colorspace, SKSurfaceProperties props)`
  - `SKSurface Create(GRRecordingContext context, GRBackendRenderTarget renderTarget, SKColorType colorType)`
  - `SKSurface Create(GRRecordingContext context, GRBackendRenderTarget renderTarget, GRSurfaceOrigin origin, SKColorType colorType)`
  - `SKSurface Create(GRRecordingContext context, GRBackendRenderTarget renderTarget, GRSurfaceOrigin origin, SKColorType colorType, SKColorSpace colorspace)`
  - `SKSurface Create(GRRecordingContext context, GRBackendRenderTarget renderTarget, SKColorType colorType, SKSurfaceProperties props)`
  - `SKSurface Create(GRRecordingContext context, GRBackendRenderTarget renderTarget, GRSurfaceOrigin origin, SKColorType colorType, SKSurfaceProperties props)`
  - `SKSurface Create(GRRecordingContext context, GRBackendRenderTarget renderTarget, GRSurfaceOrigin origin, SKColorType colorType, SKColorSpace colorspace, SKSurfaceProperties props)`
  - `SKSurface Create(GRContext context, GRGlBackendTextureDesc desc)`
  - `SKSurface Create(GRContext context, GRBackendTextureDesc desc)`
  - `SKSurface Create(GRContext context, GRGlBackendTextureDesc desc, SKSurfaceProps props)`
  - `SKSurface Create(GRContext context, GRBackendTextureDesc desc, SKSurfaceProps props)`
  - `SKSurface Create(GRContext context, GRBackendTexture texture, SKColorType colorType)`
  - `SKSurface Create(GRContext context, GRBackendTexture texture, GRSurfaceOrigin origin, SKColorType colorType)`
  - `SKSurface Create(GRContext context, GRBackendTexture texture, GRSurfaceOrigin origin, int sampleCount, SKColorType colorType)`
  - `SKSurface Create(GRContext context, GRBackendTexture texture, GRSurfaceOrigin origin, int sampleCount, SKColorType colorType, SKColorSpace colorspace)`
  - `SKSurface Create(GRContext context, GRBackendTexture texture, SKColorType colorType, SKSurfaceProperties props)`
  - `SKSurface Create(GRContext context, GRBackendTexture texture, GRSurfaceOrigin origin, SKColorType colorType, SKSurfaceProperties props)`
  - `SKSurface Create(GRContext context, GRBackendTexture texture, GRSurfaceOrigin origin, int sampleCount, SKColorType colorType, SKSurfaceProperties props)`
  - `SKSurface Create(GRContext context, GRBackendTexture texture, GRSurfaceOrigin origin, int sampleCount, SKColorType colorType, SKColorSpace colorspace, SKSurfaceProperties props)`
  - `SKSurface Create(GRRecordingContext context, GRBackendTexture texture, SKColorType colorType)`
  - `SKSurface Create(GRRecordingContext context, GRBackendTexture texture, GRSurfaceOrigin origin, SKColorType colorType)`
  - `SKSurface Create(GRRecordingContext context, GRBackendTexture texture, GRSurfaceOrigin origin, int sampleCount, SKColorType colorType)`
  - `SKSurface Create(GRRecordingContext context, GRBackendTexture texture, GRSurfaceOrigin origin, int sampleCount, SKColorType colorType, SKColorSpace colorspace)`
  - `SKSurface Create(GRRecordingContext context, GRBackendTexture texture, SKColorType colorType, SKSurfaceProperties props)`
  - `SKSurface Create(GRRecordingContext context, GRBackendTexture texture, GRSurfaceOrigin origin, SKColorType colorType, SKSurfaceProperties props)`
  - `SKSurface Create(GRRecordingContext context, GRBackendTexture texture, GRSurfaceOrigin origin, int sampleCount, SKColorType colorType, SKSurfaceProperties props)`
  - `SKSurface Create(GRRecordingContext context, GRBackendTexture texture, GRSurfaceOrigin origin, int sampleCount, SKColorType colorType, SKColorSpace colorspace, SKSurfaceProperties props)`
  - `SKSurface Create(GRContext context, bool budgeted, SKImageInfo info, int sampleCount, SKSurfaceProps props)`
  - `SKSurface Create(GRContext context, bool budgeted, SKImageInfo info)`
  - `SKSurface Create(GRContext context, bool budgeted, SKImageInfo info, int sampleCount)`
  - `SKSurface Create(GRContext context, bool budgeted, SKImageInfo info, int sampleCount, GRSurfaceOrigin origin)`
  - `SKSurface Create(GRContext context, bool budgeted, SKImageInfo info, SKSurfaceProperties props)`
  - `SKSurface Create(GRContext context, bool budgeted, SKImageInfo info, int sampleCount, SKSurfaceProperties props)`
  - `SKSurface Create(GRContext context, bool budgeted, SKImageInfo info, int sampleCount, GRSurfaceOrigin origin, SKSurfaceProperties props, bool shouldCreateWithMips)`
  - `... (properties omitted)`

`class SKSurfaceProperties`
  - `SKSurfaceProperties(SKSurfaceProps props)`
  - `SKSurfaceProperties(SKPixelGeometry pixelGeometry)`
  - `SKSurfaceProperties(UInt32 flags, SKPixelGeometry pixelGeometry)`
  - `SKSurfaceProperties(SKSurfacePropsFlags flags, SKPixelGeometry pixelGeometry)`
  - `SKSurfacePropsFlags Flags { get; }`
  - `bool IsUseDeviceIndependentFonts { get; }`
  - `SKPixelGeometry PixelGeometry { get; }`

`struct SKSurfaceProps`
  - `bool Equals(SKSurfaceProps obj)`
  - `bool Equals(object obj)`
  - `int GetHashCode()`
  - `SKSurfacePropsFlags Flags { get; set; }`
  - `SKPixelGeometry PixelGeometry { get; set; }`

`enum SKSurfacePropsFlags`
  - `values: None, UseDeviceIndependentFonts`

`class SKSurfaceReleaseDelegate`
  - `SKSurfaceReleaseDelegate(object object, IntPtr method)`
  - `IAsyncResult BeginInvoke(IntPtr address, object context, AsyncCallback callback, object object)`
  - `void EndInvoke(IAsyncResult result)`
  - `void Invoke(IntPtr address, object context)`

`class SKSvgCanvas`
  - `SKCanvas Create(SKRect bounds, Stream stream)`
  - `SKCanvas Create(SKRect bounds, SKWStream stream)`
  - `SKCanvas Create(SKRect bounds, SKXmlWriter writer)`

`class SKSwizzle`
  - `void SwapRedBlue(IntPtr pixels, int count)`
  - `void SwapRedBlue(IntPtr dest, IntPtr src, int count)`
  - `void SwapRedBlue(Span<byte> pixels)`
  - `void SwapRedBlue(ReadOnlySpan<byte> pixels, int count)`
  - `void SwapRedBlue(ReadOnlySpan<byte> dest, ReadOnlySpan<byte> src, int count)`

`enum SKTextAlign`
  - `values: Left, Center, Right`

`class SKTextBlob`
  - `int CountIntercepts(float upperBounds, float lowerBounds, SKPaint paint = ...)`
  - `SKTextBlob Create(string text, SKFont font, SKPoint origin = ...)`
  - `SKTextBlob Create(ReadOnlySpan<char> text, SKFont font, SKPoint origin = ...)`
  - `SKTextBlob Create(IntPtr text, int length, SKTextEncoding encoding, SKFont font, SKPoint origin = ...)`
  - `SKTextBlob Create(ReadOnlySpan<byte> text, SKTextEncoding encoding, SKFont font, SKPoint origin = ...)`
  - `SKTextBlob CreateHorizontal(string text, SKFont font, ReadOnlySpan<float> positions, float y)`
  - `SKTextBlob CreateHorizontal(ReadOnlySpan<char> text, SKFont font, ReadOnlySpan<float> positions, float y)`
  - `SKTextBlob CreateHorizontal(IntPtr text, int length, SKTextEncoding encoding, SKFont font, ReadOnlySpan<float> positions, float y)`
  - `SKTextBlob CreateHorizontal(ReadOnlySpan<byte> text, SKTextEncoding encoding, SKFont font, ReadOnlySpan<float> positions, float y)`
  - `SKTextBlob CreatePathPositioned(string text, SKFont font, SKPath path, SKTextAlign textAlign = ..., SKPoint origin = ...)`
  - `SKTextBlob CreatePathPositioned(ReadOnlySpan<char> text, SKFont font, SKPath path, SKTextAlign textAlign = ..., SKPoint origin = ...)`
  - `SKTextBlob CreatePathPositioned(IntPtr text, int length, SKTextEncoding encoding, SKFont font, SKPath path, SKTextAlign textAlign = ..., SKPoint origin = ...)`
  - `SKTextBlob CreatePathPositioned(ReadOnlySpan<byte> text, SKTextEncoding encoding, SKFont font, SKPath path, SKTextAlign textAlign = ..., SKPoint origin = ...)`
  - `SKTextBlob CreatePositioned(string text, SKFont font, ReadOnlySpan<SKPoint> positions)`
  - `SKTextBlob CreatePositioned(ReadOnlySpan<char> text, SKFont font, ReadOnlySpan<SKPoint> positions)`
  - `SKTextBlob CreatePositioned(IntPtr text, int length, SKTextEncoding encoding, SKFont font, ReadOnlySpan<SKPoint> positions)`
  - `SKTextBlob CreatePositioned(ReadOnlySpan<byte> text, SKTextEncoding encoding, SKFont font, ReadOnlySpan<SKPoint> positions)`
  - `SKTextBlob CreateRotationScale(string text, SKFont font, ReadOnlySpan<SKRotationScaleMatrix> positions)`
  - `SKTextBlob CreateRotationScale(ReadOnlySpan<char> text, SKFont font, ReadOnlySpan<SKRotationScaleMatrix> positions)`
  - `SKTextBlob CreateRotationScale(IntPtr text, int length, SKTextEncoding encoding, SKFont font, ReadOnlySpan<SKRotationScaleMatrix> positions)`
  - `SKTextBlob CreateRotationScale(ReadOnlySpan<byte> text, SKTextEncoding encoding, SKFont font, ReadOnlySpan<SKRotationScaleMatrix> positions)`
  - `float[] GetIntercepts(float upperBounds, float lowerBounds, SKPaint paint = ...)`
  - `void GetIntercepts(float upperBounds, float lowerBounds, Span<float> intervals, SKPaint paint = ...)`
  - `SKRect Bounds { get; }`
  - `UInt32 UniqueId { get; }`

`class SKTextBlobBuilder`
  - `SKTextBlobBuilder()`
  - `void AddHorizontalRun(ReadOnlySpan<UInt16> glyphs, SKFont font, ReadOnlySpan<float> positions, float y)`
  - `void AddHorizontalRun(SKPaint font, float y, UInt16[] glyphs, float[] positions, string text, UInt32[] clusters)`
  - `void AddHorizontalRun(SKPaint font, float y, UInt16[] glyphs, float[] positions, string text, UInt32[] clusters, SKRect bounds)`
  - `void AddHorizontalRun(SKPaint font, float y, UInt16[] glyphs, float[] positions)`
  - `void AddHorizontalRun(SKPaint font, float y, UInt16[] glyphs, float[] positions, SKRect bounds)`
  - `void AddHorizontalRun(SKPaint font, float y, UInt16[] glyphs, float[] positions, byte[] text, UInt32[] clusters)`
  - `void AddHorizontalRun(SKPaint font, float y, UInt16[] glyphs, float[] positions, byte[] text, UInt32[] clusters, SKRect bounds)`
  - `void AddHorizontalRun(SKPaint font, float y, ReadOnlySpan<UInt16> glyphs, ReadOnlySpan<float> positions)`
  - `void AddHorizontalRun(SKPaint font, float y, ReadOnlySpan<UInt16> glyphs, ReadOnlySpan<float> positions, Nullable<SKRect> bounds)`
  - `void AddHorizontalRun(SKPaint font, float y, ReadOnlySpan<UInt16> glyphs, ReadOnlySpan<float> positions, ReadOnlySpan<byte> text, ReadOnlySpan<UInt32> clusters)`
  - `void AddHorizontalRun(SKPaint font, float y, ReadOnlySpan<UInt16> glyphs, ReadOnlySpan<float> positions, ReadOnlySpan<byte> text, ReadOnlySpan<UInt32> clusters, Nullable<SKRect> bounds)`
  - `void AddPathPositionedRun(ReadOnlySpan<UInt16> glyphs, SKFont font, ReadOnlySpan<float> glyphWidths, ReadOnlySpan<SKPoint> glyphOffsets, SKPath path, SKTextAlign textAlign = ...)`
  - `void AddPositionedRun(ReadOnlySpan<UInt16> glyphs, SKFont font, ReadOnlySpan<SKPoint> positions)`
  - `void AddPositionedRun(SKPaint font, UInt16[] glyphs, SKPoint[] positions, string text, UInt32[] clusters)`
  - `void AddPositionedRun(SKPaint font, UInt16[] glyphs, SKPoint[] positions, string text, UInt32[] clusters, SKRect bounds)`
  - `void AddPositionedRun(SKPaint font, UInt16[] glyphs, SKPoint[] positions)`
  - `void AddPositionedRun(SKPaint font, UInt16[] glyphs, SKPoint[] positions, SKRect bounds)`
  - `void AddPositionedRun(SKPaint font, UInt16[] glyphs, SKPoint[] positions, byte[] text, UInt32[] clusters)`
  - `void AddPositionedRun(SKPaint font, UInt16[] glyphs, SKPoint[] positions, byte[] text, UInt32[] clusters, SKRect bounds)`
  - `void AddPositionedRun(SKPaint font, ReadOnlySpan<UInt16> glyphs, ReadOnlySpan<SKPoint> positions)`
  - `void AddPositionedRun(SKPaint font, ReadOnlySpan<UInt16> glyphs, ReadOnlySpan<SKPoint> positions, Nullable<SKRect> bounds)`
  - `void AddPositionedRun(SKPaint font, ReadOnlySpan<UInt16> glyphs, ReadOnlySpan<SKPoint> positions, ReadOnlySpan<byte> text, ReadOnlySpan<UInt32> clusters)`
  - `void AddPositionedRun(SKPaint font, ReadOnlySpan<UInt16> glyphs, ReadOnlySpan<SKPoint> positions, ReadOnlySpan<byte> text, ReadOnlySpan<UInt32> clusters, Nullable<SKRect> bounds)`
  - `void AddRotationScaleRun(ReadOnlySpan<UInt16> glyphs, SKFont font, ReadOnlySpan<SKRotationScaleMatrix> positions)`
  - `void AddRun(ReadOnlySpan<UInt16> glyphs, SKFont font, SKPoint origin = ...)`
  - `void AddRun(SKPaint font, float x, float y, UInt16[] glyphs, string text, UInt32[] clusters)`
  - `void AddRun(SKPaint font, float x, float y, UInt16[] glyphs, string text, UInt32[] clusters, SKRect bounds)`
  - `void AddRun(SKPaint font, float x, float y, UInt16[] glyphs)`
  - `void AddRun(SKPaint font, float x, float y, UInt16[] glyphs, SKRect bounds)`
  - `void AddRun(SKPaint font, float x, float y, UInt16[] glyphs, byte[] text, UInt32[] clusters)`
  - `void AddRun(SKPaint font, float x, float y, UInt16[] glyphs, byte[] text, UInt32[] clusters, SKRect bounds)`
  - `void AddRun(SKPaint font, float x, float y, ReadOnlySpan<UInt16> glyphs)`
  - `void AddRun(SKPaint font, float x, float y, ReadOnlySpan<UInt16> glyphs, Nullable<SKRect> bounds)`
  - `void AddRun(SKPaint font, float x, float y, ReadOnlySpan<UInt16> glyphs, ReadOnlySpan<byte> text, ReadOnlySpan<UInt32> clusters)`
  - `void AddRun(SKPaint font, float x, float y, ReadOnlySpan<UInt16> glyphs, ReadOnlySpan<byte> text, ReadOnlySpan<UInt32> clusters, Nullable<SKRect> bounds)`
  - `SKHorizontalRunBuffer AllocateHorizontalRun(SKFont font, int count, float y, Nullable<SKRect> bounds = ...)`
  - `SKHorizontalRunBuffer AllocateHorizontalRun(SKPaint font, int count, float y)`
  - `SKHorizontalRunBuffer AllocateHorizontalRun(SKPaint font, int count, float y, Nullable<SKRect> bounds)`
  - `SKHorizontalRunBuffer AllocateHorizontalRun(SKPaint font, int count, float y, int textByteCount)`
  - `SKHorizontalRunBuffer AllocateHorizontalRun(SKPaint font, int count, float y, int textByteCount, Nullable<SKRect> bounds)`
  - `SKPositionedRunBuffer AllocatePositionedRun(SKFont font, int count, Nullable<SKRect> bounds = ...)`
  - `SKPositionedRunBuffer AllocatePositionedRun(SKPaint font, int count)`
  - `SKPositionedRunBuffer AllocatePositionedRun(SKPaint font, int count, Nullable<SKRect> bounds)`
  - `SKPositionedRunBuffer AllocatePositionedRun(SKPaint font, int count, int textByteCount)`
  - `SKPositionedRunBuffer AllocatePositionedRun(SKPaint font, int count, int textByteCount, Nullable<SKRect> bounds)`
  - `SKRotationScaleRunBuffer AllocateRotationScaleRun(SKFont font, int count)`
  - `SKRunBuffer AllocateRun(SKFont font, int count, float x, float y, Nullable<SKRect> bounds = ...)`
  - `SKRunBuffer AllocateRun(SKPaint font, int count, float x, float y)`
  - `SKRunBuffer AllocateRun(SKPaint font, int count, float x, float y, Nullable<SKRect> bounds)`
  - `SKRunBuffer AllocateRun(SKPaint font, int count, float x, float y, int textByteCount)`
  - `SKRunBuffer AllocateRun(SKPaint font, int count, float x, float y, int textByteCount, Nullable<SKRect> bounds)`
  - `SKTextBlob Build()`

`enum SKTextEncoding`
  - `values: Utf8, Utf16, Utf32, GlyphId`

`enum SKTransferFunctionBehavior`
  - `values: Ignore, Respect`

`enum SKTrimPathEffectMode`
  - `values: Normal, Inverted`

`class SKTypeface`
  - `int CharsToGlyphs(string chars, out UInt16[] glyphs)`
  - `int CharsToGlyphs(IntPtr str, int strlen, SKEncoding encoding, out UInt16[] glyphs)`
  - `bool ContainsGlyph(int codepoint)`
  - `bool ContainsGlyphs(ReadOnlySpan<int> codepoints)`
  - `bool ContainsGlyphs(string text)`
  - `bool ContainsGlyphs(ReadOnlySpan<char> text)`
  - `bool ContainsGlyphs(ReadOnlySpan<byte> text, SKTextEncoding encoding)`
  - `bool ContainsGlyphs(IntPtr text, int length, SKTextEncoding encoding)`
  - `int CountGlyphs(string str)`
  - `int CountGlyphs(string str, SKEncoding encoding)`
  - `int CountGlyphs(ReadOnlySpan<char> str)`
  - `int CountGlyphs(byte[] str, SKEncoding encoding)`
  - `int CountGlyphs(byte[] str, SKTextEncoding encoding)`
  - `int CountGlyphs(ReadOnlySpan<byte> str, SKEncoding encoding)`
  - `int CountGlyphs(ReadOnlySpan<byte> str, SKTextEncoding encoding)`
  - `int CountGlyphs(IntPtr str, int strLen, SKEncoding encoding)`
  - `int CountGlyphs(IntPtr str, int strLen, SKTextEncoding encoding)`
  - `SKTypeface CreateDefault()`
  - `SKTypeface FromData(SKData data, int index = ...)`
  - `SKTypeface FromFamilyName(string familyName, SKTypefaceStyle style)`
  - `SKTypeface FromFamilyName(string familyName, int weight, int width, SKFontStyleSlant slant)`
  - `SKTypeface FromFamilyName(string familyName)`
  - `SKTypeface FromFamilyName(string familyName, SKFontStyle style)`
  - `SKTypeface FromFamilyName(string familyName, SKFontStyleWeight weight, SKFontStyleWidth width, SKFontStyleSlant slant)`
  - `SKTypeface FromFile(string path, int index = ...)`
  - `SKTypeface FromStream(Stream stream, int index = ...)`
  - `SKTypeface FromStream(SKStreamAsset stream, int index = ...)`
  - `SKTypeface FromTypeface(SKTypeface typeface, SKTypefaceStyle style)`
  - `UInt16 GetGlyph(int codepoint)`
  - `UInt16[] GetGlyphs(ReadOnlySpan<int> codepoints)`
  - `int GetGlyphs(string text, out UInt16[] glyphs)`
  - `int GetGlyphs(string text, SKEncoding encoding, out UInt16[] glyphs)`
  - `int GetGlyphs(byte[] text, SKEncoding encoding, out UInt16[] glyphs)`
  - `int GetGlyphs(ReadOnlySpan<byte> text, SKEncoding encoding, out UInt16[] glyphs)`
  - `int GetGlyphs(IntPtr text, int length, SKEncoding encoding, out UInt16[] glyphs)`
  - `UInt16[] GetGlyphs(string text)`
  - `UInt16[] GetGlyphs(string text, SKEncoding encoding)`
  - `UInt16[] GetGlyphs(ReadOnlySpan<char> text)`
  - `UInt16[] GetGlyphs(byte[] text, SKEncoding encoding)`
  - `UInt16[] GetGlyphs(ReadOnlySpan<byte> text, SKEncoding encoding)`
  - `UInt16[] GetGlyphs(ReadOnlySpan<byte> text, SKTextEncoding encoding)`
  - `UInt16[] GetGlyphs(IntPtr text, int length, SKEncoding encoding)`
  - `UInt16[] GetGlyphs(IntPtr text, int length, SKTextEncoding encoding)`
  - `int[] GetKerningPairAdjustments(ReadOnlySpan<UInt16> glyphs)`
  - `byte[] GetTableData(UInt32 tag)`
  - `int GetTableSize(UInt32 tag)`
  - `UInt32[] GetTableTags()`
  - `SKStreamAsset OpenStream()`
  - `SKStreamAsset OpenStream(out int ttcIndex)`
  - `SKFont ToFont()`
  - `SKFont ToFont(float size, float scaleX = ..., float skewX = ...)`
  - `bool TryGetTableData(UInt32 tag, out byte[] tableData)`
  - `bool TryGetTableData(UInt32 tag, int offset, int length, IntPtr tableData)`
  - `bool TryGetTableTags(out UInt32[] tags)`
  - `... (properties omitted)`

`enum SKTypefaceStyle`
  - `values: Normal, Bold, Italic, BoldItalic`

`enum SKVertexMode`
  - `values: Triangles, TriangleStrip, TriangleFan`

`class SKVertices`
  - `SKVertices CreateCopy(SKVertexMode vmode, SKPoint[] positions, SKColor[] colors)`
  - `SKVertices CreateCopy(SKVertexMode vmode, SKPoint[] positions, SKPoint[] texs, SKColor[] colors)`
  - `SKVertices CreateCopy(SKVertexMode vmode, SKPoint[] positions, SKPoint[] texs, SKColor[] colors, UInt16[] indices)`

`class SKWStream`
  - `void Flush()`
  - `int GetSizeOfPackedUInt32(UInt32 value)`
  - `bool NewLine()`
  - `bool Write(byte[] buffer, int size)`
  - `bool Write16(UInt16 value)`
  - `bool Write32(UInt32 value)`
  - `bool Write8(byte value)`
  - `bool WriteBigDecimalAsText(long value, int digits)`
  - `bool WriteBool(bool value)`
  - `bool WriteDecimalAsTest(int value)`
  - `bool WriteHexAsText(UInt32 value, int digits)`
  - `bool WritePackedUInt32(UInt32 value)`
  - `bool WriteScalar(float value)`
  - `bool WriteScalarAsText(float value)`
  - `bool WriteStream(SKStream input, int length)`
  - `bool WriteText(string value)`
  - `int BytesWritten { get; }`

`enum SKWebpEncoderCompression`
  - `values: Lossy, Lossless`

`struct SKWebpEncoderOptions`
  - `SKWebpEncoderOptions(SKWebpEncoderCompression compression, float quality)`
  - `SKWebpEncoderOptions(SKWebpEncoderCompression compression, float quality, SKTransferFunctionBehavior unpremulBehavior)`
  - `bool Equals(SKWebpEncoderOptions obj)`
  - `bool Equals(object obj)`
  - `int GetHashCode()`
  - `SKWebpEncoderCompression Compression { get; set; }`
  - `float Quality { get; set; }`
  - `SKTransferFunctionBehavior UnpremulBehavior { get; set; }`

`class SKXmlStreamWriter`
  - `SKXmlStreamWriter(SKWStream stream)`

`enum SKZeroInitialized`
  - `values: Yes, No`

`class SkiaExtensions`
  - `SKAlphaType GetAlphaType(SKColorType colorType, SKAlphaType alphaType = ...)`
  - `int GetBytesPerPixel(SKColorType colorType)`
  - `bool IsBgr(SKPixelGeometry pg)`
  - `bool IsHorizontal(SKPixelGeometry pg)`
  - `bool IsRgb(SKPixelGeometry pg)`
  - `bool IsVertical(SKPixelGeometry pg)`
  - `SKColorChannel ToColorChannel(SKDisplacementMapEffectChannelSelectorType channelSelectorType)`
  - `SKColorSpaceTransferFn ToColorSpaceTransferFn(SKColorSpaceRenderTargetGamma gamma)`
  - `SKColorSpaceTransferFn ToColorSpaceTransferFn(SKNamedGamma gamma)`
  - `SKColorSpaceXyz ToColorSpaceXyz(SKColorSpaceGamut gamut)`
  - `SKColorSpaceXyz ToColorSpaceXyz(SKMatrix44 matrix)`
  - `SKColorType ToColorType(GRPixelConfig config)`
  - `SKFilterQuality ToFilterQuality(SKBitmapResizeMethod method)`
  - `UInt32 ToGlSizedFormat(SKColorType colorType)`
  - `UInt32 ToGlSizedFormat(GRPixelConfig config)`
  - `GRPixelConfig ToPixelConfig(SKColorType colorType)`
  - `SKShaderTileMode ToShaderTileMode(SKMatrixConvolutionTileMode tileMode)`
  - `SKTextEncoding ToTextEncoding(SKEncoding encoding)`

`class SkiaSharpVersion`
  - `bool CheckNativeLibraryCompatible(bool throwIfIncompatible = ...)`
  - `Version Native { get; }`
  - `Version NativeMinimum { get; }`

`class StringUtilities`
  - `byte[] GetEncodedText(string text, SKEncoding encoding)`
  - `byte[] GetEncodedText(string text, SKTextEncoding encoding)`
  - `byte[] GetEncodedText(ReadOnlySpan<char> text, SKTextEncoding encoding)`
  - `string GetString(IntPtr data, int dataLength, SKTextEncoding encoding)`
  - `string GetString(byte[] data, SKTextEncoding encoding)`
  - `string GetString(byte[] data, int index, int count, SKTextEncoding encoding)`
  - `string GetString(ReadOnlySpan<byte> data, SKTextEncoding encoding)`
  - `string GetString(ReadOnlySpan<byte> data, int index, int count, SKTextEncoding encoding)`
  - `int GetUnicodeCharacterCode(string character, SKTextEncoding encoding)`

---
881 public type(s) from 6 assembly(ies).
