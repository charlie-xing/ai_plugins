import Foundation

/// 动态插件元数据
struct PluginMetadata: Codable {
    let apiVersion: String
    let minAppVersion: String?
    let permissions: [String]
    let lifecycle: LifecycleConfig?
    let assets: [String]?

    struct LifecycleConfig: Codable {
        let autoInit: Bool
        let singleton: Bool
    }
}

/// 动态插件模型
struct DynamicPlugin: Identifiable, Hashable {
    let id: String
    let name: String
    let version: String
    let author: String
    let description: String
    let mode: PluginMode
    let entry: String
    let directory: URL
    let metadata: PluginMetadata
    let isSystemPlugin: Bool

    /// 转换为旧的Plugin模型（用于兼容）
    func toLegacyPlugin() -> Plugin {
        let scriptPath = directory.appendingPathComponent(entry)
        return Plugin(
            name: name,
            description: description,
            author: author,
            version: version,
            entryFunction: "runPlugin",
            mode: mode,
            filePath: scriptPath
        )
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: DynamicPlugin, rhs: DynamicPlugin) -> Bool {
        lhs.id == rhs.id
    }
}

/// plugin.json的完整结构
struct PluginManifest: Codable {
    let id: String
    let name: String
    let version: String
    let author: String
    let description: String
    let mode: String
    let entry: String
    let api: PluginMetadata
    let permissions: [String]?
    let lifecycle: PluginMetadata.LifecycleConfig?
    let assets: [String]?
}

/// 动态插件管理器 - 支持从外部目录加载插件
@MainActor
class DynamicPluginManager {
    static let shared = DynamicPluginManager()

    private init() {
        createPluginDirectoriesIfNeeded()
    }

    // MARK: - 插件搜索路径

    /// 用户插件目录
    private var userPluginsPath: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/ai_plugins/plugins")
    }

    /// 系统插件目录（内置插件）
    private var systemPluginsPath: URL? {
        guard let resourcePath = Bundle.main.resourcePath else { return nil }
        return URL(fileURLWithPath: resourcePath).appendingPathComponent("plugins")
    }

    /// 所有插件搜索路径
    private var searchPaths: [URL] {
        var paths = [userPluginsPath]
        if let systemPath = systemPluginsPath {
            paths.append(systemPath)
        }
        return paths
    }

    // MARK: - 目录管理

    /// 创建必要的插件目录
    private func createPluginDirectoriesIfNeeded() {
        let fileManager = FileManager.default

        // 创建用户插件目录
        if !fileManager.fileExists(atPath: userPluginsPath.path) {
            do {
                try fileManager.createDirectory(
                    at: userPluginsPath,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                print("DynamicPluginManager: Created user plugins directory at \(userPluginsPath.path)")
            } catch {
                print("DynamicPluginManager: Failed to create plugins directory: \(error)")
            }
        }
    }

    // MARK: - 插件发现

    /// 发现所有可用插件
    /// - Returns: 发现的动态插件数组
    func discoverPlugins() -> [DynamicPlugin] {
        var allPlugins: [DynamicPlugin] = []

        // 从用户目录加载
        let userPlugins = scanDirectory(userPluginsPath, isSystemPlugin: false)
        allPlugins.append(contentsOf: userPlugins)
        print("DynamicPluginManager: Found \(userPlugins.count) user plugins")

        // 从系统目录加载
        if let systemPath = systemPluginsPath {
            let systemPlugins = scanDirectory(systemPath, isSystemPlugin: true)
            allPlugins.append(contentsOf: systemPlugins)
            print("DynamicPluginManager: Found \(systemPlugins.count) system plugins")
        }

        print("DynamicPluginManager: Total \(allPlugins.count) plugins discovered")
        return allPlugins
    }

    /// 扫描指定目录下的插件
    private func scanDirectory(_ url: URL, isSystemPlugin: Bool) -> [DynamicPlugin] {
        var plugins: [DynamicPlugin] = []
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: url.path) else {
            return plugins
        }

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            for item in contents {
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory),
                   isDirectory.boolValue {
                    // 检查是否包含plugin.json
                    if let plugin = loadPlugin(from: item, isSystemPlugin: isSystemPlugin) {
                        plugins.append(plugin)
                    }
                }
            }
        } catch {
            print("DynamicPluginManager: Error scanning directory \(url.path): \(error)")
        }

        return plugins
    }

    /// 从插件目录加载插件
    private func loadPlugin(from directory: URL, isSystemPlugin: Bool) -> DynamicPlugin? {
        let manifestPath = directory.appendingPathComponent("plugin.json")

        guard FileManager.default.fileExists(atPath: manifestPath.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: manifestPath)
            let manifest = try JSONDecoder().decode(PluginManifest.self, from: data)

            // 验证入口文件存在
            let entryPath = directory.appendingPathComponent(manifest.entry)
            guard FileManager.default.fileExists(atPath: entryPath.path) else {
                print("DynamicPluginManager: Entry file not found: \(entryPath.path)")
                return nil
            }

            // 构建元数据
            let metadata = PluginMetadata(
                apiVersion: manifest.api.apiVersion,
                minAppVersion: manifest.api.minAppVersion,
                permissions: manifest.permissions ?? manifest.api.permissions,
                lifecycle: manifest.lifecycle ?? manifest.api.lifecycle,
                assets: manifest.assets ?? manifest.api.assets
            )

            let plugin = DynamicPlugin(
                id: manifest.id,
                name: manifest.name,
                version: manifest.version,
                author: manifest.author,
                description: manifest.description,
                mode: PluginMode(rawValue: manifest.mode) ?? .unknown,
                entry: manifest.entry,
                directory: directory,
                metadata: metadata,
                isSystemPlugin: isSystemPlugin
            )

            print("DynamicPluginManager: Loaded plugin '\(plugin.name)' v\(plugin.version)")
            return plugin

        } catch {
            print("DynamicPluginManager: Failed to load plugin from \(directory.path): \(error)")
            return nil
        }
    }

    // MARK: - 插件加载

    /// 加载插件的JavaScript代码
    /// - Parameter plugin: 要加载的插件
    /// - Returns: JavaScript代码字符串
    func loadPluginScript(_ plugin: DynamicPlugin) -> String? {
        let scriptPath = plugin.directory.appendingPathComponent(plugin.entry)

        do {
            let script = try String(contentsOf: scriptPath, encoding: .utf8)
            print("DynamicPluginManager: Loaded script for '\(plugin.name)' (\(script.count) bytes)")
            return script
        } catch {
            print("DynamicPluginManager: Failed to load script for '\(plugin.name)': \(error)")
            return nil
        }
    }

    /// 加载插件的CSS样式（如果存在）
    /// - Parameter plugin: 要加载的插件
    /// - Returns: CSS代码字符串
    func loadPluginStyles(_ plugin: DynamicPlugin) -> String? {
        guard let assets = plugin.metadata.assets,
              let cssFile = assets.first(where: { $0.hasSuffix(".css") }) else {
            return nil
        }

        let cssPath = plugin.directory.appendingPathComponent(cssFile)

        guard FileManager.default.fileExists(atPath: cssPath.path) else {
            return nil
        }

        do {
            let css = try String(contentsOf: cssPath, encoding: .utf8)
            print("DynamicPluginManager: Loaded styles for '\(plugin.name)' (\(css.count) bytes)")
            return css
        } catch {
            print("DynamicPluginManager: Failed to load styles for '\(plugin.name)': \(error)")
            return nil
        }
    }

    // MARK: - 插件热重载

    /// 重新加载指定插件
    /// - Parameter pluginId: 插件ID
    /// - Returns: 重新加载后的插件，如果失败返回nil
    func reloadPlugin(_ pluginId: String) -> DynamicPlugin? {
        let allPlugins = discoverPlugins()
        return allPlugins.first { $0.id == pluginId }
    }

    // MARK: - 插件验证

    /// 验证插件权限
    /// - Parameters:
    ///   - plugin: 要验证的插件
    ///   - requiredPermission: 需要的权限
    /// - Returns: 是否有权限
    func hasPermission(_ plugin: DynamicPlugin, _ requiredPermission: String) -> Bool {
        return plugin.metadata.permissions.contains(requiredPermission)
    }

    /// 获取用户插件目录路径（用于UI显示）
    func getUserPluginsPath() -> String {
        return userPluginsPath.path
    }
}
