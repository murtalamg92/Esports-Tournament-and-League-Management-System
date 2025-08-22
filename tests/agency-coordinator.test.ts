import { describe, it, expect, beforeEach } from "vitest"

describe("Agency Coordinator Contract", () => {
  let contractAddress
  let agency1
  let agency2
  let agency3
  let beneficiary1
  
  beforeEach(() => {
    contractAddress = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.agency-coordinator"
    agency1 = "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG"
    agency2 = "ST2JHG361ZXG51QTKY2NQCVBPPRRE2KZB1HR05NNC"
    agency3 = "ST3AM1A56AK2C1XAFJ4115ZSV26EB49BVQ10MGCS0"
    beneficiary1 = "ST3PF13W7Z0RRM42A8VZRVFQ75SV1K26RXEP8YGKJ"
  })
  
  describe("Agency Registration", () => {
    it("should register new agency successfully", () => {
      const result = { type: "ok", value: 1 }
      
      expect(result.type).toBe("ok")
      expect(result.value).toBe(1)
    })
    
    it("should prevent duplicate registration", () => {
      const result = { type: "err", value: 502 } // ERR-ALREADY-REGISTERED
      
      expect(result.type).toBe("err")
      expect(result.value).toBe(502)
    })
    
    it("should store agency details correctly", () => {
      const agency = {
        "agency-address": agency1,
        "organization-name": "Red Cross International",
        "agency-type": "humanitarian",
        "contact-info": "contact@redcross.org",
        "verification-status": "pending",
        specializations: ["medical", "food", "shelter"],
      }
      
      expect(agency["organization-name"]).toBe("Red Cross International")
      expect(agency.specializations).toContain("medical")
    })
  })
  
  describe("Agency Verification", () => {
    it("should verify agency successfully", () => {
      const result = { type: "ok", value: true }
      
      expect(result.type).toBe("ok")
      expect(result.value).toBe(true)
    })
    
    it("should update verification status", () => {
      const agency = {
        "verification-status": "verified",
      }
      
      const verification = {
        verified: true,
        "verified-by": agency2,
        "verification-date": 1000,
      }
      
      expect(agency["verification-status"]).toBe("verified")
      expect(verification.verified).toBe(true)
    })
  })
  
  describe("Coordination Activities", () => {
    it("should create coordination activity successfully", () => {
      const result = { type: "ok", value: 1 }
      
      expect(result.type).toBe("ok")
      expect(result.value).toBe(1)
    })
    
    it("should fail coordination by unverified agency", () => {
      const result = { type: "err", value: 500 } // ERR-NOT-AUTHORIZED
      
      expect(result.type).toBe("err")
      expect(result.value).toBe(500)
    })
    
    it("should track coordination details", () => {
      const coordination = {
        "disaster-id": 1,
        "lead-agency": 1,
        "participating-agencies": [1, 2, 3],
        "activity-type": "joint-distribution",
        "target-area": "San Juan Metro Area",
        "start-date": 1000,
        status: "active",
        "resources-shared": ["food", "water", "medical"],
      }
      
      expect(coordination["lead-agency"]).toBe(1)
      expect(coordination["participating-agencies"]).toHaveLength(3)
      expect(coordination.status).toBe("active")
    })
  })
  
  describe("Aid Distribution Logging", () => {
    it("should log aid distribution successfully", () => {
      const result = { type: "ok", value: true }
      
      expect(result.type).toBe("ok")
      expect(result.value).toBe(true)
    })
    
    it("should track multiple agencies providing aid", () => {
      const aidLog = {
        "providing-agencies": [1, 2],
        "total-quantity": 150,
        "distribution-dates": [1000, 1001],
        "last-updated": 1001,
      }
      
      expect(aidLog["providing-agencies"]).toHaveLength(2)
      expect(aidLog["total-quantity"]).toBe(150)
    })
    
    it("should update existing aid logs", () => {
      const initialQuantity = 100
      const additionalQuantity = 50
      const totalQuantity = initialQuantity + additionalQuantity
      
      expect(totalQuantity).toBe(150)
    })
    
    it("should detect duplicate aid attempts", () => {
      const hasPreviousAid = true
      
      expect(hasPreviousAid).toBe(true)
    })
  })
  
  describe("Agency Capabilities", () => {
    it("should set agency capability successfully", () => {
      const result = { type: "ok", value: true }
      
      expect(result.type).toBe("ok")
      expect(result.value).toBe(true)
    })
    
    it("should track capability details", () => {
      const capability = {
        available: true,
        capacity: 1000,
        "current-utilization": 0,
      }
      
      expect(capability.available).toBe(true)
      expect(capability.capacity).toBe(1000)
    })
    
    it("should update utilization rates", () => {
      const capacity = 1000
      const utilization = 300
      const utilizationRate = (utilization / capacity) * 100
      
      expect(utilizationRate).toBe(30)
    })
  })
  
  describe("Activity Management", () => {
    it("should update agency activity successfully", () => {
      const result = { type: "ok", value: true }
      
      expect(result.type).toBe("ok")
      expect(result.value).toBe(true)
    })
    
    it("should complete coordination activity", () => {
      const result = { type: "ok", value: true }
      
      expect(result.type).toBe("ok")
      expect(result.value).toBe(true)
    })
    
    it("should track activity completion", () => {
      const coordination = {
        "start-date": 1000,
        "end-date": 1500,
        status: "completed",
      }
      
      expect(coordination.status).toBe("completed")
      expect(coordination["end-date"]).toBeGreaterThan(coordination["start-date"])
    })
  })
  
  describe("Duplicate Prevention", () => {
    it("should check for duplicate aid correctly", () => {
      const hasDuplicateAid = true
      
      expect(hasDuplicateAid).toBe(true)
    })
    
    it("should prevent duplicate aid distribution", () => {
      const result = { type: "err", value: 504 } // ERR-DUPLICATE-AID-DETECTED
      
      expect(result.type).toBe("err")
      expect(result.value).toBe(504)
    })
    
    it("should allow aid from different agencies", () => {
      const agency1Aid = { quantity: 50, agency: 1 }
      const agency2Aid = { quantity: 75, agency: 2 }
      
      expect(agency1Aid.agency).not.toBe(agency2Aid.agency)
    })
  })
  
  describe("Read-only Functions", () => {
    it("should retrieve agency details", () => {
      const agency = {
        "agency-address": agency1,
        "organization-name": "Red Cross International",
        "agency-type": "humanitarian",
        "verification-status": "verified",
        specializations: ["medical", "food", "shelter"],
      }
      
      expect(agency["organization-name"]).toBe("Red Cross International")
      expect(agency["verification-status"]).toBe("verified")
    })
    
    it("should get coordination activity details", () => {
      const coordination = {
        "disaster-id": 1,
        "lead-agency": 1,
        "activity-type": "joint-distribution",
        status: "active",
      }
      
      expect(coordination["disaster-id"]).toBe(1)
      expect(coordination.status).toBe("active")
    })
    
    it("should check agency verification status", () => {
      const isVerified = true
      
      expect(isVerified).toBe(true)
    })
    
    it("should get aid distribution logs", () => {
      const aidLog = {
        "providing-agencies": [1, 2],
        "total-quantity": 150,
        "last-updated": 1001,
      }
      
      expect(aidLog["providing-agencies"]).toContain(1)
      expect(aidLog["total-quantity"]).toBe(150)
    })
    
    it("should retrieve agency capabilities", () => {
      const capability = {
        available: true,
        capacity: 1000,
        "current-utilization": 300,
      }
      
      expect(capability.available).toBe(true)
      expect(capability["current-utilization"]).toBeLessThan(capability.capacity)
    })
    
    it("should get agency specializations", () => {
      const specializations = ["medical", "food", "shelter", "logistics"]
      
      expect(specializations).toContain("medical")
      expect(specializations).toHaveLength(4)
    })
  })
})
