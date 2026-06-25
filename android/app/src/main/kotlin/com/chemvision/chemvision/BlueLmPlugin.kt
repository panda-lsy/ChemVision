package com.chemvision.chemvision

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*

/**
 * BlueLM 端侧大模型 Flutter 插件
 *
 * 通过 MethodChannel 封装 LlmManager SDK，
 * 提供 init / generate / callVit / interrupt / release 接口。
 */
class BlueLmPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var llmManager: Any? = null // LlmManager 实例（运行时反射避免编译依赖）
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())

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
        val modelPath = call.argument<String>("modelPath") ?: return result.error("INVALID_ARGS", "modelPath required", null)
        val multimodal = call.argument<Boolean>("multimodal") ?: false
        val nCtx = call.argument<Int>("nCtx") ?: 2048
        val nThreads = call.argument<Int>("nThreads") ?: 4
        val npuPower = call.argument<Int>("npuPower") ?: 100

        scope.launch {
            try {
                android.util.Log.d("BlueLmPlugin", "init: path=$modelPath, multimodal=$multimodal")

                val managerClass = Class.forName("com.vivo.llmsdk.LlmManager")
                val manager = managerClass.getDeclaredConstructor().newInstance()

                val configClass = Class.forName("com.vivo.llmsdk.LlmConfig")
                val config = configClass.getDeclaredConstructor().newInstance()

                configClass.getDeclaredField("modelPath").set(config, modelPath)
                configClass.getDeclaredField("multimodal").set(config, multimodal)
                configClass.getDeclaredField("nCtx").set(config, nCtx)
                configClass.getDeclaredField("nThreads").set(config, nThreads)
                configClass.getDeclaredField("npuPower").set(config, npuPower)

                val initMethod = managerClass.getMethod("init", configClass)
                val ret = initMethod.invoke(manager, config) as Int

                android.util.Log.d("BlueLmPlugin", "init result: $ret")
                llmManager = if (ret == 0) manager else null
                withContext(Dispatchers.Main) {
                    result.success(ret)
                }
            } catch (e: ClassNotFoundException) {
                // LlmManager SDK 未集成
                withContext(Dispatchers.Main) {
                    result.error("SDK_NOT_FOUND", "BlueLM SDK not available: ${e.message}", null)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("INIT_FAILED", e.message, null)
                }
            }
        }
    }

    private fun handleGenerate(call: MethodCall, result: Result) {
        val prompt = call.argument<String>("prompt") ?: return result.error("INVALID_ARGS", "prompt required", null)
        val manager = llmManager ?: return result.error("NOT_INITIALIZED", "BlueLM not initialized", null)

        scope.launch {
            try {
                val responseBuilder = StringBuilder()
                val managerClass = manager.javaClass

                // 创建 TokenCallback
                val callbackClass = Class.forName("com.vivo.llmsdk.TokenCallback")
                val callback = java.lang.reflect.Proxy.newProxyInstance(
                    callbackClass.classLoader,
                    arrayOf(callbackClass)
                ) { _, method, args ->
                    when (method.name) {
                        "onToken" -> responseBuilder.append(args[0] as String)
                        "onComplete" -> { /* done */ }
                        "onError" -> {
                            val code = args[0] as Int
                            val msg = args[1] as String
                            throw Exception("BlueLM error $code: $msg")
                        }
                    }
                    null
                }

                // 调用 generate
                val generateMethod = managerClass.getMethod("generate", String::class.java, callbackClass)
                generateMethod.invoke(manager, prompt, callback)

                // 等待完成（简单轮询）
                delay(100) // 给回调一点时间

                withContext(Dispatchers.Main) {
                    result.success(responseBuilder.toString())
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("GENERATE_FAILED", e.message, null)
                }
            }
        }
    }

    private fun handleCallVit(call: MethodCall, result: Result) {
        val imageBytes = call.argument<ByteArray>("imageBytes")
        val width = call.argument<Int>("width") ?: return result.error("INVALID_ARGS", "width required", null)
        val height = call.argument<Int>("height") ?: return result.error("INVALID_ARGS", "height required", null)
        val manager = llmManager ?: return result.error("NOT_INITIALIZED", "BlueLM not initialized", null)

        scope.launch {
            try {
                val managerClass = manager.javaClass
                val vitMethod = managerClass.getMethod("callVit", ByteArray::class.java, Int::class.java, Int::class.java)
                val ret = vitMethod.invoke(manager, imageBytes, width, height) as Int
                withContext(Dispatchers.Main) {
                    result.success(ret)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("VIT_FAILED", e.message, null)
                }
            }
        }
    }

    private fun handleInterrupt(result: Result) {
        val manager = llmManager
        if (manager == null) {
            result.success(null)
            return
        }
        try {
            val method = manager.javaClass.getMethod("interrupt")
            method.invoke(manager)
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
                val method = it.javaClass.getMethod("release")
                method.invoke(it)
            }
        } catch (_: Exception) {}
        llmManager = null
    }
}
