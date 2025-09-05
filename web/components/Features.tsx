'use client'

import { motion, useInView } from 'framer-motion'
import { useRef } from 'react'
import { 
  MessageCircle, 
  Shield, 
  Zap, 
  Smartphone, 
  Globe, 
  Lock,
  ArrowRight,
  CheckCircle
} from 'lucide-react'

export default function Features() {
  const sectionRef = useRef(null)
  const isInView = useInView(sectionRef, { once: true, margin: "-100px" })

  const features = [
    {
      icon: MessageCircle,
      title: "WhatsApp Integration",
      description: "Send payment links directly through WhatsApp messages. No app downloads required.",
      details: ["Click-to-pay links", "Native WhatsApp sharing", "QR code support"],
      color: "from-green-500 to-emerald-500"
    },
    {
      icon: Shield,
      title: "Passkey Security", 
      description: "WebAuthn biometric authentication. Your device is your wallet.",
      details: ["Biometric login", "No seed phrases", "Device-native security"],
      color: "from-blue-500 to-cyan-500"
    },
    {
      icon: Zap,
      title: "Instant Settlements",
      description: "Built on Base L2 for lightning-fast and cheap transactions.",
      details: ["Sub-second finality", "Low gas fees", "ERC-4337 powered"],
      color: "from-purple-500 to-pink-500"
    },
    {
      icon: Globe,
      title: "Cross-Border Payments",
      description: "Send money globally with just a phone number hash for privacy.",
      details: ["Global reach", "Privacy preserved", "No KYC barriers"],
      color: "from-orange-500 to-red-500"
    },
    {
      icon: Smartphone,
      title: "Mobile First",
      description: "Designed for mobile users with progressive web app experience.",
      details: ["Responsive design", "Offline support", "App-like experience"],
      color: "from-teal-500 to-green-500"
    },
    {
      icon: Lock,
      title: "Self-Custody",
      description: "You own your keys through smart contract wallets and passkeys.",
      details: ["Non-custodial", "Account recovery", "Smart contract security"],
      color: "from-indigo-500 to-purple-500"
    }
  ]

  const containerVariants = {
    hidden: { opacity: 0 },
    visible: {
      opacity: 1,
      transition: {
        staggerChildren: 0.2,
        delayChildren: 0.1
      }
    }
  }

  const itemVariants = {
    hidden: { y: 50, opacity: 0, scale: 0.9 },
    visible: { 
      y: 0, 
      opacity: 1, 
      scale: 1
    }
  }

  return (
    <section id="features" ref={sectionRef} className="py-20 lg:py-32 bg-white relative overflow-hidden">
      {/* Background Pattern */}
      <div className="absolute inset-0">
        <div className="absolute inset-y-0 left-0 w-1/2 bg-gradient-to-r from-gray-50 to-transparent" />
        <div className="absolute inset-y-0 right-0 w-1/2 bg-gradient-to-l from-cyan-50 to-transparent" />
      </div>

      <div className="container mx-auto px-6 lg:px-8 relative z-10">
        {/* Section Header */}
        <motion.div
          initial={{ y: 50, opacity: 0 }}
          animate={isInView ? { y: 0, opacity: 1 } : {}}
          transition={{ duration: 0.8 }}
          className="text-center mb-16 lg:mb-24"
        >
          <motion.div
            initial={{ scale: 0 }}
            animate={isInView ? { scale: 1 } : {}}
            transition={{ duration: 0.5, delay: 0.2 }}
            className="inline-flex items-center space-x-2 bg-gradient-to-r from-emerald-100 to-cyan-100 border border-emerald-200 rounded-full px-4 py-2 mb-6"
          >
            <Zap className="w-4 h-4 text-emerald-600" />
            <span className="text-sm font-medium text-emerald-700">Powerful Features</span>
          </motion.div>
          
          <h2 className="text-3xl md:text-4xl lg:text-5xl font-bold mb-6">
            <span className="bg-gradient-to-r from-gray-800 to-gray-600 bg-clip-text text-transparent">
              Everything you need for
            </span>
            <br />
            <span className="bg-gradient-to-r from-emerald-600 to-cyan-600 bg-clip-text text-transparent">
              seamless payments
            </span>
          </h2>
          
          <p className="text-lg lg:text-xl text-gray-600 max-w-3xl mx-auto leading-relaxed">
            Bro Pay combines the best of Web3 technology with the simplicity of WhatsApp, 
            creating the most user-friendly payment experience ever built.
          </p>
        </motion.div>

        {/* Features Grid */}
        <motion.div
          variants={containerVariants}
          initial="hidden"
          animate={isInView ? "visible" : "hidden"}
          className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8 mb-16"
        >
          {features.map((feature) => (
            <motion.div
              key={feature.title}
              variants={itemVariants}
              transition={{ duration: 0.6, ease: "easeOut" }}
              className="group relative"
            >
              <div className="bg-white border border-gray-200 rounded-2xl p-8 shadow-lg hover:shadow-2xl transition-all duration-500 h-full relative overflow-hidden group-hover:scale-105">
                {/* Background Gradient */}
                <div className={`absolute top-0 left-0 w-full h-1 bg-gradient-to-r ${feature.color}`} />
                
                {/* Hover Effect */}
                <div className={`absolute inset-0 bg-gradient-to-br ${feature.color} opacity-0 group-hover:opacity-5 transition-opacity duration-500`} />
                
                {/* Icon */}
                <motion.div
                  whileHover={{ scale: 1.1, rotate: 5 }}
                  className={`inline-flex items-center justify-center w-14 h-14 bg-gradient-to-r ${feature.color} rounded-xl mb-6 shadow-lg`}
                >
                  <feature.icon className="w-7 h-7 text-white" />
                </motion.div>

                {/* Content */}
                <h3 className="text-xl font-semibold text-gray-800 mb-3 group-hover:text-gray-900">
                  {feature.title}
                </h3>
                
                <p className="text-gray-600 mb-6 leading-relaxed">
                  {feature.description}
                </p>

                {/* Feature Details */}
                <ul className="space-y-2">
                  {feature.details.map((detail, idx) => (
                    <motion.li
                      key={idx}
                      initial={{ opacity: 0, x: -20 }}
                      animate={isInView ? { opacity: 1, x: 0 } : {}}
                      transition={{ duration: 0.5, delay: 0.3 + idx * 0.1 }}
                      className="flex items-center space-x-2 text-sm text-gray-600"
                    >
                      <CheckCircle className="w-4 h-4 text-emerald-500 flex-shrink-0" />
                      <span>{detail}</span>
                    </motion.li>
                  ))}
                </ul>

                {/* Hover Arrow */}
                <motion.div
                  initial={{ opacity: 0, x: -10 }}
                  whileHover={{ opacity: 1, x: 0 }}
                  className="absolute bottom-6 right-6"
                >
                  <ArrowRight className="w-5 h-5 text-gray-400 group-hover:text-gray-600 transition-colors duration-300" />
                </motion.div>
              </div>
            </motion.div>
          ))}
        </motion.div>

        {/* Stats Section */}
        <motion.div
          initial={{ y: 50, opacity: 0 }}
          animate={isInView ? { y: 0, opacity: 1 } : {}}
          transition={{ duration: 0.8, delay: 0.5 }}
          className="bg-gradient-to-r from-emerald-50 via-cyan-50 to-blue-50 rounded-3xl p-8 lg:p-12 border border-gray-200"
        >
          <div className="text-center mb-8">
            <h3 className="text-2xl lg:text-3xl font-bold text-gray-800 mb-4">
              Trusted by thousands of users
            </h3>
            <p className="text-gray-600 max-w-2xl mx-auto">
              Join the growing community of users who have discovered the future of payments
            </p>
          </div>
          
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-8">
            {[
              { value: "10K+", label: "Active Users" },
              { value: "$2.5M", label: "Volume Processed" },
              { value: "50+", label: "Countries" },
              { value: "99.9%", label: "Uptime" }
            ].map((stat, statIndex) => (
              <motion.div
                key={stat.label}
                initial={{ scale: 0, opacity: 0 }}
                animate={isInView ? { scale: 1, opacity: 1 } : {}}
                transition={{ duration: 0.6, delay: 0.7 + statIndex * 0.1 }}
                className="text-center"
              >
                <div className="text-2xl lg:text-3xl font-bold bg-gradient-to-r from-emerald-600 to-cyan-600 bg-clip-text text-transparent mb-2">
                  {stat.value}
                </div>
                <div className="text-sm text-gray-600">{stat.label}</div>
              </motion.div>
            ))}
          </div>
        </motion.div>
      </div>
    </section>
  )
}