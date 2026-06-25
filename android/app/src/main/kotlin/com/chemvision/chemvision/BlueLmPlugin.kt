package com.chemvision.chemvision

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*

class BlueLmPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var llmManager: Any? = null
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())
    private val TAG = "BlueLmPlugin"

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.chemvision/bluelm")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        scope.cancel()
        releaseLlm()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "init" -> handleInit(call, result)
            "generate" -> handleGenerate(call, result)
            "callVit" -> handleCallVit(call, result)
            "interrupt" -> handleInterrupt(result)
            "release" -> handleRelease(result)
            else -> result.notImplemented()
        }
    }

    private fun handleInit(call: MethodCall, result: Result) {
        val modelPath = call.argument<String>("modelPath")
            ?: return result.error("INVALID_ARGS", "modelPath required", null)
        val multimodal = call.argument<Boolean>("multimodal") ?: false
        val nCtx = call.argument<Int>("nCtx") ?: 2048
        val nThreads = call.argument<Int>("nThreads") ?: 4
        val npuPower = call.argument<Int>("npuPower") ?: 100

        android.util.Log.d(TAG, "handleInit: path=$modelPath, multimodal=$multimodal, nCtx=$nCtx")

        scope.launch {
            try {
                // 1. 检查类是否可用
                val managerClass = try {
                    Class.forName("com.vivo.llmsdk.LlmManager")
                } catch (e: ClassNotFoundException) {
                    android.util.Log.e(TAG, "LlmManager class not found: ${e.message}")
                    withContext(Dispatchers.Main) {
                        result.error("SDK_NOT_FOUND", "LlmManager class not found: ${e.message}", null)
                    }
                    return@launch
                }

                val configClass = try {
                    Class.forName("com.vivo.llmsdk.LlmConfig")
                } catch (e: ClassNotFoundException) {
                    android.util.Log.e(TAG, "LlmConfig class not found: ${e.message}")
                    withContext(Dispatchers.Main) {
                        result.error("SDK_NOT_FOUND", "LlmConfig class not found: ${e.message}", null)
                    }
                    return@launch
                }

                android.util.Log.d(TAG, "Classes found, creating instances...")

                // 2. 创建实例
                val manager = managerClass.getDeclaredConstructor().newInstance()
                val config = configClass.getDeclaredConstructor().newInstance()

                // 3. 设置字段
                try {
                    configClass.getDeclaredField("modelPath").set(config, modelPath)
                    configClass.getDeclaredField("multimodal").set(config, multimodal)
                    configClass.getDeclaredField("nCtx").set(config, nCtx)
                    configClass.getDeclaredField("nThreads").set(config, nThreads)
                    configClass.getDeclaredField("npuPower").set(config, npuPower)
                    android.util.Log.d(TAG, "Config fields set successfully")
                } catch (e: NoSuchFieldException) {
                    android.util.Log.e(TAG, "Config field not found: ${e.message}")
                    // 尝试列出所有字段
                    configClass.declaredFields.forEach {
                        android.util.Log.d(TAG, "  field: ${it.name} (${it.type})")
                    }
                    withContext(Dispatchers.Main) {
                        result.error("CONFIG_ERROR", "Field not found: ${e.message}", null)
                    }
                    return@launch
                }

                // 4. 调用 init
                val initMethod = try {
                    managerClass.getMethod("init", configClass)
                } catch (e: NoSuchMethodException) {
                    android.util.Log.e(TAG, "init method not found: ${e.message}")
                    managerClass.methods.forEach {
                        android.util.Log.d(TAG, "  method: ${it.name}")
                    }
                    withContext(Dispatchers.Main) {
                        result.error("METHOD_ERROR", "init method not found: ${e.message}", null)
                    }
                    return@launch
                }

                android.util.Log.d(TAG, "Calling LlmManager.init()...")
                val ret = initMethod.invoke(manager, config) as Int
                android.util.Log.d(TAG, "LlmManager.init() returned: $ret")

                llmManager = if (ret == 0) manager else null
                withContext(Dispatchers.Main) {
                    result.success(ret)
                }
            } catch (e: Exception) {
                android.util.Log.e(TAG, "init exception: ${e.javaClass.simpleName}: ${e.message}")
                android.util.Log.e(TAG, "stacktrace: ${e.stackTraceToString()}")
                withContext(Dispatchers.Main) {
                    result.error("INIT_FAILED", "${e.javaClass.simpleName}: ${e.message}", null)
                }
            }
        }
    }

    private fun handleGenerate(call: MethodCall, result: Result) {
        val prompt = call.argument<String>("prompt")
            ?: return result.error("INVALID_ARGS", "prompt required", null)
        val manager = llmManager
            ?: return result.error("NOT_INITIALIZED", "BlueLM not initialized", null)

        android.util.Log.d(TAG, "generate: prompt=${prompt.take(50)}...")

        scope.launch {
            try {
                val responseBuilder = StringBuilder()
                val managerClass = manager.javaClass

                val callbackClass = Class.forName("com.vivo.llmsdk.TokenCallback")
                val callback = java.lang.reflect.Proxy.newProxyInstance(
                    callbackClass.classLoader,
                    arrayOf(callbackClass)
                ) { _, method, args ->
                    when (method.name) {
                        "onToken" -> responseBuilder.append(args[0] as String)
                        "onComplete" -> android.util.Log.d(TAG, "generate complete")
                        "onError" -> {
                            val code = args[0] as Int
                            val msg = args[1] as String
                            android.util.Log.e(TAG, "generate error: $code $msg")
                        }
                    }
                    null
                }

                val generateMethod = managerClass.getMethod("generate", String::class.java, callbackClass)
                generateMethod.invoke(manager, prompt, callback)

                // 等待推理完成
                delay(5000)

                android.util.Log.d(TAG, "generate result: ${responseBuilder.toString().take(100)}")
                withContext(Dispatchers.Main) {
                    result.success(responseBuilder.toString())
                }
            } catch (e: Exception) {
                android.util.Log.e(TAG, "generate exception: ${e.message}")
                withContext(Dispatchers.Main) {
                    result.error("GENERATE_FAILED", e.message, null)
                }
            }
        }
    }

    private fun handleCallVit(call: MethodCall, result: Result) {
        val imageBytes = call.argument<ByteArray>("imageBytes")
        val width = call.argument<Int>("width")
            ?: return result.error("INVALID_ARGS", "width required", null)
        val height = call.argument<Int>("height")
            ?: return result.error("INVALID_ARGS", "height required", null)
        val manager = llmManager
            ?: return result.error("NOT_INITIALIZED", "BlueLM not initialized", null)

        scope.launch {
            try {
                val managerClass = manager.javaClass
                val vitMethod = managerClass.getMethod("callVit", ByteArray::class.java, Int::class.java, Int::class.java)
                val ret = vitMethod.invoke(manager, imageBytes, width, height) as Int
                android.util.Log.d(TAG, "callVit result: $ret")
                withContext(Dispatchers.Main) {
                    result.success(ret)
                }
            } catch (e: Exception) {
                android.util.Log.e(TAG, "callVit exception: ${e.message}")
                withContext(Dispatchers.Main) {
                    result.error("VIT_FAILED", e.message, null)
                }
            }
        }
    }

    private fun handleInterrupt(result: Result) {
        val manager = llmManager
        if (manager == null) { result.success(null); return }
        try {
            manager.javaClass.getMethod("interrupt").invoke(manager)
            result.success(null)
        } catch (e: Exception) {
            result.error("INTERRUPT_FAILED", e.message, null)
        }
    }

    private fun handleRelease(result: Result) {
        releaseLlm()
        result.success(null)
    }

    private fun releaseLlm() {
        try {
            llmManager?.let {
                it.javaClass.getMethod("release").invoke(it)
            }
        } catch (_: Exception) {}
        llmManager = null
    }
}
