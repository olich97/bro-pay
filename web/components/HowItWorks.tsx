'use client'

import { motion, useInView } from 'framer-motion'
import { useRef } from 'react'
import { 
  Link, 
  MessageCircle, 
  CheckCircle,
  ArrowDown,
  Fingerprint,
  Send,
  Wallet
} from 'lucide-react'

export default function HowItWorks() {
  const sectionRef = useRef(null)
  const isInView = useInView(sectionRef, { once: true, margin: "-100px" })

  const steps = [
    {
      icon: Fingerprint,
      title: "Authenticate with Passkey",
      description: "Use your device's biometric authentication to create your secure account",
      details: "No passwords, no seed phrases. Your device becomes your secure wallet.",
      color: "from-purple-500 to-pink-500",
      position: "left"
    },
    {
      icon: Link,
      title: "Generate Payment Link", 
      description: "Create a secure payment capsule with recipient details and amount",
      details: "Each link is cryptographically signed and contains all payment information.",
      color: "from-blue-500 to-cyan-500", 
      position: "right"
    },
    {
      icon: MessageCircle,
      title: "Share via WhatsApp",
      description: "Send the payment link through WhatsApp like any other message",
      details: "Recipients can pay instantly by clicking the link - no app required.",
      color: "from-green-500 to-emerald-500",
      position: "left"
    },
    {
      icon: CheckCircle,
      title: "Instant Settlement",
      description: "Funds are instantly transferred on Base L2 with minimal fees",
      details: "Smart contracts handle escrow and release funds upon verification.",
      color: "from-emerald-500 to-teal-500",
      position: "right"
    }
  ]

  const containerVariants = {
    hidden: { opacity: 0 },
    visible: {
      opacity: 1,
      transition: {
        staggerChildren: 0.3,
        delayChildren: 0.2
      }
    }
  }

  const stepVariants = {
    hidden: { 
      opacity: 0, 
      x: -100,
      y: 50 
    },
    visible: { 
      opacity: 1, 
      x: 0, 
      y: 0
    }
  }

  return (
    <section id="how-it-works" ref={sectionRef} className="py-20 lg:py-32 bg-gradient-to-b from-gray-50 to-white relative overflow-hidden">
      {/* Background Elements */}
      <div className="absolute inset-0 overflow-hidden">
        <motion.div
          animate={{
            rotate: [0, 360],
            scale: [1, 1.2, 1],
          }}
          transition={{
            duration: 30,
            repeat: Infinity,
            ease: 'easeInOut',
          }}
          className="absolute -top-40 -right-40 w-80 h-80 bg-gradient-to-r from-cyan-300/20 to-blue-300/20 rounded-full blur-3xl"
        />
        <motion.div
          animate={{
            rotate: [360, 0],
            scale: [1, 0.8, 1],
          }}
          transition={{
            duration: 25,
            repeat: Infinity,
            ease: 'easeInOut',
            delay: 10,
          }}
          className="absolute -bottom-40 -left-40 w-96 h-96 bg-gradient-to-r from-emerald-300/20 to-green-300/20 rounded-full blur-3xl"
        />
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
            className="inline-flex items-center space-x-2 bg-white border border-gray-200 rounded-full px-4 py-2 mb-6 shadow-sm"
          >
            <Send className="w-4 h-4 text-emerald-600" />
            <span className="text-sm font-medium text-gray-700">Simple Process</span>
          </motion.div>
          
          <h2 className="text-3xl md:text-4xl lg:text-5xl font-bold mb-6">
            <span className="bg-gradient-to-r from-gray-800 to-gray-600 bg-clip-text text-transparent">
              How it works in
            </span>
            <br />
            <span className="bg-gradient-to-r from-emerald-600 to-cyan-600 bg-clip-text text-transparent">
              4 simple steps
            </span>
          </h2>
          
          <p className="text-lg lg:text-xl text-gray-600 max-w-3xl mx-auto leading-relaxed">
            Send money as easily as sharing a WhatsApp message. No complex wallets, 
            no crypto knowledge required.
          </p>
        </motion.div>

        {/* Steps */}
        <motion.div
          variants={containerVariants}
          initial="hidden"
          animate={isInView ? "visible" : "hidden"}
          className="relative"
        >
          {/* Connecting Line */}
          <div className="hidden lg:block absolute left-1/2 transform -translate-x-px top-0 bottom-0">
            <motion.div
              initial={{ height: 0 }}
              animate={isInView ? { height: '100%' } : {}}
              transition={{ duration: 2, delay: 0.5 }}
              className="w-px bg-gradient-to-b from-emerald-200 via-cyan-200 to-emerald-200"
            />
          </div>

          {steps.map((step, index) => (
            <motion.div
              key={step.title}
              variants={stepVariants}
              transition={{ duration: 0.8, ease: "easeOut" }}
              className={`relative flex items-center ${
                step.position === 'left' 
                  ? 'lg:flex-row' 
                  : 'lg:flex-row-reverse'
              } flex-col lg:mb-16 mb-12 last:mb-0`}
            >
              {/* Step Content */}
              <div className={`lg:w-5/12 ${step.position === 'left' ? 'lg:pr-12' : 'lg:pl-12'}`}>
                <motion.div
                  whileHover={{ scale: 1.02 }}
                  className="bg-white border border-gray-200 rounded-2xl p-8 shadow-lg hover:shadow-xl transition-all duration-300 relative overflow-hidden group"
                >
                  {/* Background Gradient */}
                  <div className={`absolute inset-0 bg-gradient-to-br ${step.color} opacity-0 group-hover:opacity-5 transition-opacity duration-300`} />
                  
                  {/* Step Number */}
                  <div className="absolute -top-4 -left-4 w-12 h-12 bg-white border-4 border-gray-100 rounded-full flex items-center justify-center shadow-lg">
                    <span className="text-lg font-bold text-gray-700">{index + 1}</span>
                  </div>

                  {/* Icon */}
                  <motion.div
                    whileHover={{ scale: 1.1 }}
                    className={`inline-flex items-center justify-center w-16 h-16 bg-gradient-to-r ${step.color} rounded-xl mb-6 shadow-lg`}
                  >
                    <step.icon className="w-8 h-8 text-white" />
                  </motion.div>

                  <h3 className="text-xl lg:text-2xl font-semibold text-gray-800 mb-4">
                    {step.title}
                  </h3>
                  
                  <p className="text-gray-600 mb-4 text-lg leading-relaxed">
                    {step.description}
                  </p>
                  
                  <p className="text-sm text-gray-500 italic">
                    {step.details}
                  </p>
                </motion.div>
              </div>

              {/* Center Circle (Desktop) */}
              <div className="hidden lg:flex lg:w-2/12 justify-center">
                <motion.div
                  initial={{ scale: 0 }}
                  animate={isInView ? { scale: 1 } : {}}
                  transition={{ duration: 0.5, delay: 0.5 + index * 0.2 }}
                  className={`w-16 h-16 bg-gradient-to-r ${step.color} rounded-full flex items-center justify-center shadow-xl z-10`}
                >
                  <step.icon className="w-8 h-8 text-white" />
                </motion.div>
              </div>

              {/* Spacer */}
              <div className="hidden lg:block lg:w-5/12" />

              {/* Arrow (Mobile) */}
              {index < steps.length - 1 && (
                <motion.div
                  initial={{ opacity: 0, y: -20 }}
                  animate={isInView ? { opacity: 1, y: 0 } : {}}
                  transition={{ duration: 0.5, delay: 0.8 + index * 0.3 }}
                  className="lg:hidden flex justify-center my-6"
                >
                  <ArrowDown className="w-8 h-8 text-gray-400" />
                </motion.div>
              )}
            </motion.div>
          ))}
        </motion.div>

        {/* Demo CTA */}
        <motion.div
          initial={{ y: 50, opacity: 0 }}
          animate={isInView ? { y: 0, opacity: 1 } : {}}
          transition={{ duration: 0.8, delay: 1.5 }}
          className="text-center mt-16 lg:mt-24"
        >
          <div className="bg-gradient-to-r from-emerald-50 via-cyan-50 to-blue-50 rounded-2xl p-8 lg:p-12 border border-gray-200">
            <Wallet className="w-16 h-16 mx-auto mb-6 text-emerald-600" />
            <h3 className="text-2xl lg:text-3xl font-bold text-gray-800 mb-4">
              Ready to try it out?
            </h3>
            <p className="text-gray-600 mb-8 max-w-2xl mx-auto">
              Experience the future of payments with our interactive demo. 
              See how easy it is to send money via WhatsApp.
            </p>
            <motion.button
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              className="bg-gradient-to-r from-emerald-500 to-cyan-500 hover:from-emerald-600 hover:to-cyan-600 text-white px-8 py-4 rounded-full font-semibold text-lg transition-all duration-300 shadow-xl hover:shadow-2xl inline-flex items-center space-x-2"
            >
              <span>Try Interactive Demo</span>
              <motion.div
                animate={{ x: [0, 5, 0] }}
                transition={{ duration: 1.5, repeat: Infinity, ease: 'easeInOut' }}
              >
                <ArrowDown className="w-5 h-5 rotate-[-90deg]" />
              </motion.div>
            </motion.button>
          </div>
        </motion.div>
      </div>
    </section>
  )
}